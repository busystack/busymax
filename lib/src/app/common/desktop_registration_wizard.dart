import '../../core/auth/oauth_registration.dart';

enum RegistrationWizardPage { methods, configuration, instructions }

final class DesktopRegistrationWizard {
  var page = RegistrationWizardPage.methods;
  var method = DesktopConnectionMethod.custom;
  var returningFromInstructions = false;
  var launching = false;
  int? failedStep;
  int _linkRevision = 0;

  RegistrationWizardPage? get previousPage => switch (page) {
    RegistrationWizardPage.methods => null,
    RegistrationWizardPage.configuration => RegistrationWizardPage.methods,
    RegistrationWizardPage.instructions => RegistrationWizardPage.configuration,
  };

  void navigate(RegistrationWizardPage target) {
    returningFromInstructions =
        page == RegistrationWizardPage.instructions &&
        target == RegistrationWizardPage.configuration;
    page = target;
    _linkRevision++;
    launching = false;
    failedStep = null;
  }

  int beginLinkLaunch() {
    launching = true;
    failedStep = null;
    return ++_linkRevision;
  }

  bool isCurrentLink(int revision) =>
      page == RegistrationWizardPage.instructions && revision == _linkRevision;

  void finishLinkLaunch({required bool opened, required int step}) {
    launching = false;
    if (!opened) failedStep = step;
  }
}
