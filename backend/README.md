# agtiaz PayPal Payment Integration

This is a complete PayPal payment integration system for the agtiaz Teacher Flutter mobile app. It includes a Node.js Express backend and a simple HTML/JavaScript frontend.

## Features

- **Backend (Node.js + Express)**:
  - Create PayPal orders
  - Capture payments after approval
  - Handle PayPal webhooks
  - In-memory database simulation (easily replaceable with MySQL/MongoDB)
  - Environment variable configuration

- **Frontend (HTML + JavaScript)**:
  - Dynamic plan display based on URL parameters
  - PayPal JavaScript SDK integration
  - Responsive payment button
  - Success/failure status messages
  - Native mobile apps should verify purchases through their server APIs

## Project Structure

```
backend/
├── server.js          # Main Express server
├── package.json       # Dependencies and scripts
├── .env.example       # Environment variables template
├── public/
│   └── payment.html   # Payment page frontend
└── README.md          # This file
```

## Prerequisites

- Node.js (version 14 or higher)
- PayPal Developer Account (Sandbox)

## Setup Instructions

### 1. PayPal Setup

1. Go to [PayPal Developer Dashboard](https://developer.paypal.com/dashboard/applications/sandbox)
2. Create a new app or use existing sandbox app
3. Get your Client ID and Client Secret from the app settings

### 2. Backend Setup

1. Navigate to the backend directory:
   ```bash
   cd nafis_nafsak_teacher/backend
   ```

2. Install dependencies:
   ```bash
   npm install
   ```

3. Copy environment variables:
   ```bash
   cp .env.example .env
   ```

4. Edit `.env` file and add your PayPal credentials:
   ```
   CLIENT_ID=your_paypal_client_id_here
   CLIENT_SECRET=your_paypal_client_secret_here
   PAYPAL_API_URL=https://api-m.sandbox.paypal.com
   PORT=3000
   ```

### 3. Update Frontend PayPal Client ID

In `public/payment.html`, replace `YOUR_CLIENT_ID` in the PayPal SDK script tag with your actual Client ID:

```html
<script src="https://www.paypal.com/sdk/js?client-id=YOUR_ACTUAL_CLIENT_ID&currency=USD&intent=capture"></script>
```

## Running the Application

### Start the Backend Server

```bash
npm start
```

For development with auto-restart:
```bash
npm run dev
```

The server will start on `http://localhost:3000`

### Access the Payment Page

Open your browser and go to:
```
http://localhost:3000/payment.html?plan=silver&userId=12345
```

URL Parameters:
- `plan`: The subscription plan (silver, gold, platinum)
- `userId`: The user ID from your mobile app

Example URLs:
- `http://localhost:3000/payment.html?plan=silver&userId=user123`
- `http://localhost:3000/payment.html?plan=gold&userId=user456`

## API Endpoints

### POST /api/create-order
Creates a PayPal order for the specified plan and user.

**Request Body:**
```json
{
  "plan": "silver",
  "userId": "user123"
}
```

**Response:**
```json
{
  "success": true,
  "orderId": "PAYPAL_ORDER_ID",
  "message": "Order created successfully"
}
```

### POST /api/capture-order
Captures payment after user approval.

**Request Body:**
```json
{
  "orderId": "PAYPAL_ORDER_ID"
}
```

**Response:**
```json
{
  "success": true,
  "message": "Payment captured successfully",
  "transactionId": "PAYPAL_TRANSACTION_ID"
}
```

### POST /api/webhook
Handles PayPal webhook notifications.

### GET /api/subscription/:userId
Checks subscription status for a user.

## Subscription Plans

Currently configured plans:
- **Silver**: $9.99 (30 days)
- **Gold**: $19.99 (30 days)
- **Platinum**: $29.99 (30 days)

You can modify plans in `server.js` in the `plans` object.

## Mobile App Integration

### For Flutter

The mobile app now uses native in-app purchase flows. Keep payment activation tied to the server-side purchase verification endpoint.

## Database Migration

The current implementation uses in-memory storage. To migrate to a real database:

1. Replace the `orders` and `subscriptions` objects with database models
2. Update the CRUD operations to use your database ORM (e.g., Mongoose for MongoDB, Sequelize for SQL)
3. Add proper error handling and data validation

## Production Deployment

1. Change `PAYPAL_API_URL` to `https://api-m.paypal.com` in `.env`
2. Set up proper webhook verification for security
3. Use a production database
4. Set up HTTPS
5. Configure proper CORS settings
6. Add rate limiting and security middleware

## Troubleshooting

### Common Issues

1. **"Invalid client_id" error**: Check your PayPal Client ID in both `.env` and `payment.html`
2. **CORS errors**: Ensure your backend allows requests from your frontend domain
3. **Webhook not receiving**: For local development, use ngrok to expose your local server
4. **Payment button not showing**: Check console for JavaScript errors

### Testing

Use PayPal Sandbox accounts for testing:
- Create test buyer/seller accounts in PayPal Developer Dashboard
- Use sandbox credentials in `.env`

## Support

For PayPal integration issues, refer to:
- [PayPal Developer Documentation](https://developer.paypal.com/docs/)
- [PayPal Checkout Integration Guide](https://developer.paypal.com/docs/checkout/)

For issues with this implementation, check the server logs and browser console for error messages.
