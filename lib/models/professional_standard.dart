enum ProfessionalDomain {
  ethics('standardsValuesDomain'),
  knowledge('standardsKnowledgeDomain'),
  practice('standardsPracticeDomain');

  const ProfessionalDomain(this.titleKey);
  final String titleKey;
}

class ProfessionalStandard {
  const ProfessionalStandard(this.id, this.domain);
  final String id;
  final ProfessionalDomain domain;
  String get titleKey => 'standard${id}Title';
  String get fullTitleKey => 'standard${id}FullTitle';
  String get descriptionKey => 'standard${id}Description';
}

// Grouping follows the standards table supplied for the general license exam.
const professionalStandards = [
  ProfessionalStandard('Values', ProfessionalDomain.ethics),
  ProfessionalStandard('Development', ProfessionalDomain.ethics),
  ProfessionalStandard('Community', ProfessionalDomain.ethics),
  ProfessionalStandard('Language', ProfessionalDomain.knowledge),
  ProfessionalStandard('Learner', ProfessionalDomain.knowledge),
  ProfessionalStandard('Specialty', ProfessionalDomain.knowledge),
  ProfessionalStandard('Teaching', ProfessionalDomain.knowledge),
  ProfessionalStandard('Planning', ProfessionalDomain.practice),
  ProfessionalStandard('Environment', ProfessionalDomain.practice),
  ProfessionalStandard('Assessment', ProfessionalDomain.practice),
];
