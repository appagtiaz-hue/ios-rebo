const express = require('express');
const axios = require('axios');
const crypto = require('crypto');
const cors = require('cors');
require('dotenv').config();

const app = express();
const PORT = process.env.PORT || 3000;

// Middleware
app.use(cors());
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// Serve static files (for payment.html)
app.use(express.static('public'));

// In-memory database simulation
let orders = {}; // orderId -> { userId, planId, status, amount }
let subscriptions = {}; // userId -> { planId, status, startDate, endDate }

// PayPal API configuration
const PAYPAL_API_URL = process.env.PAYPAL_API_URL || 'https://api-m.sandbox.paypal.com';
const CLIENT_ID = process.env.CLIENT_ID;
const CLIENT_SECRET = process.env.CLIENT_SECRET;

// Subscription plans
const plans = {
  silver: { name: 'Silver Plan', price: 9.99, duration: 30 }, // 30 days
  gold: { name: 'Gold Plan', price: 19.99, duration: 30 },
  premium: { name: 'Premium Plan', price: 29.99, duration: 30 }
};

// Helper function to get PayPal access token
async function getPayPalAccessToken() {
  try {
    const auth = Buffer.from(`${CLIENT_ID}:${CLIENT_SECRET}`).toString('base64');
    const response = await axios.post(`${PAYPAL_API_URL}/v1/oauth2/token`, 'grant_type=client_credentials', {
      headers: {
        'Authorization': `Basic ${auth}`,
        'Content-Type': 'application/x-www-form-urlencoded'
      }
    });
    return response.data.access_token;
  } catch (error) {
    console.error('Error getting PayPal access token:', error.response?.data || error.message);
    throw error;
  }
}

// API Endpoints

// 1. Create PayPal Order
app.post('/api/create-order', async (req, res) => {
  try {
    const { plan, userId } = req.body;

    if (!plan || !userId) {
      return res.status(400).json({ success: false, message: 'Plan and userId are required' });
    }

    if (!plans[plan]) {
      return res.status(400).json({ success: false, message: 'Invalid plan' });
    }

    const planDetails = plans[plan];
    const accessToken = await getPayPalAccessToken();

    // Create PayPal order
    const orderData = {
      intent: 'CAPTURE',
      purchase_units: [{
        amount: {
          currency_code: 'SAR',
          value: planDetails.price.toString()
        },
        description: `${planDetails.name} Subscription`,
        custom_id: `${userId}_${plan}`  // Format: userId_plan for webhook identification
      }]
    };

    const response = await axios.post(`${PAYPAL_API_URL}/v2/checkout/orders`, orderData, {
      headers: {
        'Authorization': `Bearer ${accessToken}`,
        'Content-Type': 'application/json'
      }
    });

    const orderId = response.data.id;

    // Store order in memory
    orders[orderId] = {
      userId,
      planId: plan,
      status: 'CREATED',
      amount: planDetails.price,
      createdAt: new Date()
    };

    console.log(`Order created: ${orderId} for user ${userId}, plan ${plan}`);

    res.json({
      success: true,
      orderId: orderId,
      message: 'Order created successfully'
    });

  } catch (error) {
    console.error('Error creating order:', error.response?.data || error.message);
    res.status(500).json({
      success: false,
      message: 'Failed to create order',
      error: error.message
    });
  }
});

// 2. Capture PayPal Order
app.post('/api/capture-order', async (req, res) => {
  try {
    const { orderId } = req.body;

    if (!orderId) {
      return res.status(400).json({ success: false, message: 'Order ID is required' });
    }

    if (!orders[orderId]) {
      return res.status(404).json({ success: false, message: 'Order not found' });
    }

    const order = orders[orderId];
    const accessToken = await getPayPalAccessToken();

    // Capture the order
    const response = await axios.post(`${PAYPAL_API_URL}/v2/checkout/orders/${orderId}/capture`, {}, {
      headers: {
        'Authorization': `Bearer ${accessToken}`,
        'Content-Type': 'application/json'
      }
    });

    // Update order status
    orders[orderId].status = 'COMPLETED';
    orders[orderId].capturedAt = new Date();

    // Update user subscription
    const planDetails = plans[order.planId];
    const startDate = new Date();
    const endDate = new Date();
    endDate.setDate(endDate.getDate() + planDetails.duration);

    subscriptions[order.userId] = {
      planId: order.planId,
      status: 'active',
      startDate,
      endDate,
      transactionId: response.data.purchase_units[0].payments.captures[0].id
    };

    console.log(`Order captured: ${orderId}, subscription activated for user ${order.userId}`);

    res.json({
      success: true,
      message: 'Payment captured successfully',
      transactionId: response.data.purchase_units[0].payments.captures[0].id
    });

  } catch (error) {
    console.error('Error capturing order:', error.response?.data || error.message);
    res.status(500).json({
      success: false,
      message: 'Failed to capture payment',
      error: error.message
    });
  }
});

app.post('/api/webhook', express.raw({type: 'application/json'}), (req, res) => {
  try {
    const webhookBody = req.body.toString();
    const parsedBody = JSON.parse(webhookBody);
    const eventType = parsedBody.event_type;

    console.log('Webhook received:', eventType);

    // For sandbox/development, we'll trust the webhook without full verification
    // In production, you should verify the webhook signature properly using PayPal's verification

    if (eventType === 'PAYMENT.CAPTURE.COMPLETED') {
      const resource = parsedBody.resource;
      const orderId = resource.order_id;
      const captureId = resource.id;
      const customId = resource.custom_id; // This should contain userId and plan info

      if (orders[orderId]) {
        const order = orders[orderId];
        
        // Update order status
        order.status = 'COMPLETED';
        order.captureId = captureId;
        order.completedAt = new Date();

        // Parse custom_id if it contains plan info (format: userId_plan)
        if (customId) {
          const [userId, planId] = customId.split('_');
          if (userId && planId && plans[planId]) {
            const planDetails = plans[planId];
            const startDate = new Date();
            const endDate = new Date(startDate);
            endDate.setDate(endDate.getDate() + planDetails.duration);

            // Update user subscription
            subscriptions[userId] = {
              planId: planId,
              status: 'active',
              startDate,
              endDate,
              transactionId: captureId
            };

            console.log(`Subscription activated for user ${userId} - Plan: ${planId}, Transaction: ${captureId}`);
          }
        }

        console.log(`Payment capture completed for order ${orderId}`);
      }
    } else if (eventType === 'CHECKOUT.ORDER.APPROVED') {
      const orderId = parsedBody.resource.id;

      if (orders[orderId]) {
        orders[orderId].webhookReceived = true;
        orders[orderId].webhookData = parsedBody;

        console.log(`Order approved webhook for ${orderId}`);
      }
    }

    // Always respond with 200 to acknowledge receipt
    res.status(200).send('OK');

  } catch (error) {
    console.error('Error processing webhook:', error);
    res.status(500).send('Error processing webhook');
  }
});

// Additional endpoints for checking subscription status
app.get('/api/subscription/:userId', (req, res) => {
  const { userId } = req.params;

  const subscription = subscriptions[userId];
  if (subscription) {
    res.json({
      success: true,
      subscription: subscription
    });
  } else {
    res.json({
      success: true,
      subscription: null
    });
  }
});

// Start server
app.listen(PORT, () => {
  console.log(`PayPal Payment Server running on port ${PORT}`);
  console.log(`Payment page available at: https://localhost:${PORT}/payment.html`);
});
