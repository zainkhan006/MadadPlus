import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'services/emergency_request_state.dart';
import 'theme/app_theme.dart';

class EmergencyFlow extends StatelessWidget {
  const EmergencyFlow({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<EmergencyRequestState>();

    switch (state.currentScreen) {
      case EmergencyScreen.splash:
        return const _SplashScreen();
      case EmergencyScreen.onboarding:
        return const _OnboardingScreen();
      case EmergencyScreen.login:
        return const _LoginScreen();
      case EmergencyScreen.otp:
        return const _OtpScreen();
      case EmergencyScreen.roleChoice:
        return const _RoleChoiceScreen();
      case EmergencyScreen.register:
        return const _RegisterScreen();
      case EmergencyScreen.driverJob:
        return const _DriverJobScreen();
      case EmergencyScreen.services:
        return const _UserTabScreen(
          title: 'Services',
          tab: _UserTab.services,
        );
      case EmergencyScreen.requests:
        return const _UserTabScreen(
          title: 'Requests',
          tab: _UserTab.requests,
        );
      case EmergencyScreen.profile:
        return const _ProfileScreen();
      case EmergencyScreen.home:
        return const _HomeScreen();
      case EmergencyScreen.emergencyType:
        return const _EmergencyTypeScreen();
      case EmergencyScreen.emergencyLocation:
        return const _EmergencyLocationScreen();
      case EmergencyScreen.emergencyDetails:
        return const _EmergencyDetailsScreen();
      case EmergencyScreen.emergencyConfirm:
        return const _EmergencyConfirmScreen();
      case EmergencyScreen.emergencySearch:
        return const _EmergencySearchScreen();
      case EmergencyScreen.emergencyAssigned:
        return const _EmergencyAssignedScreen();
      case EmergencyScreen.emergencyBusy:
        return const _EmergencyBusyScreen();
      case EmergencyScreen.emergencyEnRoute:
        return const _EmergencyEnRouteScreen();
      case EmergencyScreen.emergencyApproaching:
        return const _EmergencyApproachingScreen();
      case EmergencyScreen.emergencyArrived:
        return const _EmergencyArrivedScreen();
      case EmergencyScreen.emergencyComplete:
        return const _EmergencyCompleteScreen();
    }
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return _FlowFrame(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(
            Icons.health_and_safety_rounded,
            color: AppColors.red,
            size: 84,
          ),
          const SizedBox(height: AppSpacing.space5),
          Text(
            'Madad+',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineLarge,
          ),
          const SizedBox(height: AppSpacing.space2),
          Text(
            'Emergency help and trusted local services.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge
                ?.copyWith(color: AppColors.muted),
          ),
          const SizedBox(height: AppSpacing.space6),
          _ActionButton(
            label: 'GET STARTED',
            onPressed: () {
              context.read<EmergencyRequestState>().goTo(
                EmergencyScreen.onboarding,
              );
            },
          ),
        ],
      ),
    );
  }
}

class _OnboardingScreen extends StatelessWidget {
  const _OnboardingScreen();

  @override
  Widget build(BuildContext context) {
    return _FlowFrame(
      title: 'Welcome',
      onBack: () {
        context.read<EmergencyRequestState>().goTo(EmergencyScreen.splash);
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppSpacing.space6),
          const Icon(
            Icons.support_agent_rounded,
            color: AppColors.green,
            size: 72,
          ),
          const SizedBox(height: AppSpacing.space5),
          Text(
            'Help when you need it',
            style: Theme.of(context).textTheme.headlineLarge,
          ),
          const SizedBox(height: AppSpacing.space3),
          Text(
            'Request emergency help or find a trusted local service provider.',
            style: Theme.of(context).textTheme.bodyLarge
                ?.copyWith(color: AppColors.muted),
          ),
          const SizedBox(height: AppSpacing.space6),
          _ActionButton(
            label: 'CONTINUE',
            onPressed: () {
              context.read<EmergencyRequestState>().goTo(EmergencyScreen.login);
            },
          ),
        ],
      ),
    );
  }
}

class _LoginScreen extends StatelessWidget {
  const _LoginScreen();

  @override
  Widget build(BuildContext context) {
    return _FlowFrame(
      title: 'Sign in',
      onBack: () {
        context.read<EmergencyRequestState>().goTo(EmergencyScreen.onboarding);
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Existing account',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: AppSpacing.space2),
          Text(
            'We will send a verification code. Demo mode does not send a real SMS.',
            style: Theme.of(context).textTheme.bodyLarge
                ?.copyWith(color: AppColors.muted),
          ),
          const SizedBox(height: AppSpacing.space5),
          const TextField(
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              labelText: 'Phone number',
              hintText: '+92 300 1234567',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: AppSpacing.space5),
          _ActionButton(
            label: 'CONTINUE',
            onPressed: () {
              context.read<EmergencyRequestState>().continueSignIn();
            },
          ),
          const SizedBox(height: AppSpacing.space3),
          TextButton(
            onPressed: () {
              context.read<EmergencyRequestState>().continueDriverSignIn();
            },
            child: const Text('Sign in as driver'),
          ),
          TextButton(
            onPressed: () {
              context.read<EmergencyRequestState>().goTo(
                EmergencyScreen.roleChoice,
              );
            },
            child: const Text('Create account'),
          ),
        ],
      ),
    );
  }
}

class _OtpScreen extends StatelessWidget {
  const _OtpScreen();

  @override
  Widget build(BuildContext context) {
    return _FlowFrame(
      title: 'Verify phone',
      onBack: () {
        context.read<EmergencyRequestState>().backFromOtp();
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Enter verification code',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: AppSpacing.space2),
          Text(
            'Demo mode: tap verify to continue.',
            style: Theme.of(context).textTheme.bodyLarge
                ?.copyWith(color: AppColors.muted),
          ),
          const SizedBox(height: AppSpacing.space5),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [_OtpBox(), _OtpBox(), _OtpBox(), _OtpBox()],
          ),
          const SizedBox(height: AppSpacing.space5),
          _ActionButton(
            label: 'VERIFY',
            onPressed: () {
              context.read<EmergencyRequestState>().verifyCode();
            },
          ),
        ],
      ),
    );
  }
}

class _RoleChoiceScreen extends StatelessWidget {
  const _RoleChoiceScreen();

  @override
  Widget build(BuildContext context) {
    return _FlowFrame(
      title: 'How are you joining?',
      onBack: () {
        context.read<EmergencyRequestState>().goTo(EmergencyScreen.login);
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppSpacing.space6),
          _ActionButton(
            label: 'Register as Driver',
            onPressed: () {
              context.read<EmergencyRequestState>().chooseAccount(
                AccountPath.driver,
              );
            },
          ),
          const SizedBox(height: AppSpacing.space3),
          _ActionButton(
            label: 'Register as User',
            onPressed: () {
              context.read<EmergencyRequestState>().chooseAccount(
                AccountPath.user,
              );
            },
          ),
        ],
      ),
    );
  }
}

class _RegisterScreen extends StatelessWidget {
  const _RegisterScreen();

  @override
  Widget build(BuildContext context) {
    final driver =
        context.watch<EmergencyRequestState>().accountPath ==
        AccountPath.driver;

    return _FlowFrame(
      title: driver ? 'Register as Driver' : 'Register as User',
      onBack: () {
        context.read<EmergencyRequestState>().goTo(EmergencyScreen.roleChoice);
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'This wireframe accepts what you type.',
            style: Theme.of(context).textTheme.bodyLarge
                ?.copyWith(color: AppColors.muted),
          ),
          const SizedBox(height: AppSpacing.space5),
          const TextField(
            decoration: InputDecoration(
              labelText: 'Name',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: AppSpacing.space3),
          const TextField(
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              labelText: 'Phone number',
              border: OutlineInputBorder(),
            ),
          ),
          if(driver) ...[
            const SizedBox(height: AppSpacing.space3),
            const TextField(
              decoration: InputDecoration(
                labelText: 'Ambulance number',
                border: OutlineInputBorder(),
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.space5),
          _ActionButton(
            label: 'Continue',
            onPressed: () {
              context.read<EmergencyRequestState>().continueRegistration();
            },
          ),
        ],
      ),
    );
  }
}

enum _DriverJob {
  pickupBusy,
  pickupUnavailable,
  hospitalBusy,
  hospitalUnavailable,
  dropoff,
  free,
  idleUnavailable,
}

class _DriverJobScreen extends StatefulWidget {
  const _DriverJobScreen();

  @override
  State<_DriverJobScreen> createState() => _DriverJobScreenState();
}

class _DriverJobScreenState extends State<_DriverJobScreen> {
  _DriverJob job = _DriverJob.pickupBusy;
  double slide = 0;
  bool dropoffPrompted = false;

  void markUnavailable() {
    setState(() {
      switch(job) {
        case _DriverJob.pickupBusy:
          job = _DriverJob.pickupUnavailable;
        case _DriverJob.hospitalBusy:
          job = _DriverJob.hospitalUnavailable;
        case _DriverJob.free:
          job = _DriverJob.idleUnavailable;
        case _DriverJob.pickupUnavailable:
        case _DriverJob.hospitalUnavailable:
        case _DriverJob.dropoff:
        case _DriverJob.idleUnavailable:
          break;
      }
    });
  }

  void markAvailable() {
    setState(() {
      job = _DriverJob.free;
    });
  }

  void pickedUp() {
    if(job != _DriverJob.pickupBusy) {
      return;
    }

    setState(() {
      job = _DriverJob.hospitalBusy;
    });
  }

  void reachedHospital() {
    if(job != _DriverJob.hospitalBusy) {
      return;
    }

    setState(() {
      job = _DriverJob.dropoff;
      slide = 0;
    });
  }

  void confirmDropoff() {
    Navigator.of(context).pop();
    setState(() {
      job = _DriverJob.pickupBusy;
      slide = 0;
      dropoffPrompted = false;
    });
  }

  void slideTo(double value) {
    if(job != _DriverJob.dropoff) {
      return;
    }

    setState(() {
      slide = value;
    });
    if(value < 1 || dropoffPrompted) {
      return;
    }

    dropoffPrompted = true;
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Patient dropped off'),
          content: const Text('This ambulance is free again.'),
          actions: [
            TextButton(
              onPressed: confirmDropoff,
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = switch(job) {
      _DriverJob.pickupBusy || _DriverJob.pickupUnavailable => 'Pickup',
      _DriverJob.hospitalBusy ||
      _DriverJob.hospitalUnavailable => 'To hospital',
      _DriverJob.dropoff => 'Drop-off',
      _DriverJob.free || _DriverJob.idleUnavailable => 'No active call',
    };
    final status = switch(job) {
      _DriverJob.pickupBusy || _DriverJob.hospitalBusy => 'BUSY',
      _DriverJob.free => 'FREE',
      _ => 'UNAVAILABLE',
    };
    final statusColor = switch(job) {
      _DriverJob.pickupBusy || _DriverJob.hospitalBusy => AppColors.blue,
      _DriverJob.free => AppColors.green,
      _ => AppColors.orange,
    };
    final onCall =
        job == _DriverJob.pickupBusy ||
        job == _DriverJob.pickupUnavailable ||
        job == _DriverJob.hospitalBusy ||
        job == _DriverJob.hospitalUnavailable ||
        job == _DriverJob.dropoff;
    final atHospital =
        job == _DriverJob.hospitalBusy ||
        job == _DriverJob.hospitalUnavailable;
    final message = switch(job) {
      _DriverJob.pickupUnavailable =>
        'The nearest free ambulance is sent to the address the caller typed.',
      _DriverJob.hospitalUnavailable =>
        'The nearest free ambulance is sent to this ambulance so the patient can transfer.',
      _DriverJob.free => 'The dispatcher now sees this ambulance as FREE.',
      _DriverJob.idleUnavailable =>
        'The dispatcher will not send this ambulance a call.',
      _ => null,
    };
    final showMarkUnavailable =
        job == _DriverJob.pickupBusy ||
        job == _DriverJob.hospitalBusy ||
        job == _DriverJob.free;
    final showMarkAvailable =
        job == _DriverJob.pickupUnavailable ||
        job == _DriverJob.hospitalUnavailable ||
        job == _DriverJob.idleUnavailable;

    return _FlowFrame(
      title: title,
      onBack: () {
        context.read<EmergencyRequestState>().goTo(EmergencyScreen.login);
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 190,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.page,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: AppColors.line, width: 2),
            ),
            child: const Icon(
              Icons.location_on_rounded,
              color: AppColors.blue,
              size: 42,
            ),
          ),
          const SizedBox(height: AppSpacing.space3),
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.space3,
                vertical: AppSpacing.space1,
              ),
              decoration: BoxDecoration(
                color: statusColor,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                status,
                style: Theme.of(context).textTheme.labelSmall
                    ?.copyWith(color: AppColors.surface),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.space3),
          Text(
            'Location details',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: AppSpacing.space2),
          if(!onCall)
            Text(
              'No call on this ambulance.',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          if(onCall && !atHospital && job != _DriverJob.dropoff) ...[
            Text(
              'DHA Phase 5, Street 12, Near XYZ Mall',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            Text(
              'Chest pain, caller +92 300 1234567',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ],
          if(atHospital || job == _DriverJob.dropoff) ...[
            Text(
              'Indus Hospital, Korangi Crossing',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            Text(
              'Patient is on board',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ],
          if(message != null) ...[
            const SizedBox(height: AppSpacing.space4),
            Text(message, style: Theme.of(context).textTheme.bodyLarge),
          ],
          const SizedBox(height: AppSpacing.space5),
          if(showMarkUnavailable)
            _ActionButton(
              label: 'Mark as Unavailable',
              color: AppColors.orange,
              onPressed: markUnavailable,
            ),
          if(showMarkAvailable)
            _ActionButton(
              label: 'Mark as Available',
              color: AppColors.green,
              onPressed: markAvailable,
            ),
          if(job == _DriverJob.pickupBusy) ...[
            const SizedBox(height: AppSpacing.space3),
            _ActionButton(label: 'Picked up', onPressed: pickedUp),
          ],
          if(job == _DriverJob.hospitalBusy) ...[
            const SizedBox(height: AppSpacing.space3),
            _ActionButton(
              label: 'Reached the hospital',
              onPressed: reachedHospital,
            ),
          ],
          if(job == _DriverJob.dropoff) ...[
            Text(
              'Dropped off',
              style: Theme.of(context).textTheme.labelSmall,
            ),
            Slider(
              value: slide,
              label: 'Dropped off',
              onChanged: slideTo,
            ),
            Text(
              'Slide to the end to confirm.',
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: AppColors.muted),
            ),
          ],
        ],
      ),
    );
  }
}

class _HomeScreen extends StatelessWidget {
  const _HomeScreen();

  @override
  Widget build(BuildContext context) {
    return _FlowFrame(
      title: 'Karachi, DHA Phase 5',
      tab: _UserTab.home,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'How can we help?',
            style: Theme.of(context).textTheme.headlineLarge,
          ),
          const SizedBox(height: AppSpacing.space4),
          _ChoiceCard(
            icon: Icons.emergency_rounded,
            title: 'Emergency help',
            subtitle: 'Request an ambulance for a medical emergency.',
            color: AppColors.red,
            onTap: () {
              context.read<EmergencyRequestState>().goTo(
                EmergencyScreen.emergencyType,
              );
            },
          ),
          const SizedBox(height: AppSpacing.space5),
          Text(
            'Simulation mode only. For a real emergency, call 1122.',
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: AppColors.muted),
          ),
        ],
      ),
    );
  }
}

class _EmergencyTypeScreen extends StatelessWidget {
  const _EmergencyTypeScreen();

  @override
  Widget build(BuildContext context) {
    return _FlowFrame(
      emergency: true,
      title: 'Emergency help',
      tab: _UserTab.emergency,
      onBack: () {
        context.read<EmergencyRequestState>().goTo(EmergencyScreen.home);
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'What do you need?',
            style: Theme.of(context).textTheme.headlineLarge,
          ),
          const SizedBox(height: AppSpacing.space2),
          Text(
            'Ambulance requests are available in this demo.',
            style: Theme.of(context).textTheme.bodyLarge
                ?.copyWith(color: AppColors.muted),
          ),
          const SizedBox(height: AppSpacing.space4),
          _ChoiceCard(
            icon: Icons.local_hospital_rounded,
            title: 'Ambulance',
            subtitle: 'Medical emergency, accident, or injury.',
            color: AppColors.red,
            onTap: () {
              context.read<EmergencyRequestState>().goTo(
                EmergencyScreen.emergencyLocation,
              );
            },
          ),
          const SizedBox(height: AppSpacing.space5),
          const _DemoNotice(),
        ],
      ),
    );
  }
}

class _EmergencyLocationScreen extends StatelessWidget {
  const _EmergencyLocationScreen();

  @override
  Widget build(BuildContext context) {
    return _FlowFrame(
      emergency: true,
      title: 'Location',
      onBack: () {
        context.read<EmergencyRequestState>().goTo(
          EmergencyScreen.emergencyType,
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Where is the emergency?',
            style: Theme.of(context).textTheme.headlineLarge,
          ),
          const SizedBox(height: AppSpacing.space4),
          _ChoiceCard(
            icon: Icons.location_on_rounded,
            title: 'USE DEMO LOCATION',
            subtitle: 'DHA Phase 5, Street 12',
            color: AppColors.red,
            onTap: () {
              context.read<EmergencyRequestState>().goTo(
                EmergencyScreen.emergencyDetails,
              );
            },
          ),
          const SizedBox(height: AppSpacing.space4),
          const TextField(
            decoration: InputDecoration(
              labelText: 'Landmark',
              hintText: 'Near XYZ Mall, Gate 3',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: AppSpacing.space5),
          _ActionButton(
            label: 'CONTINUE',
            emergency: true,
            onPressed: () {
              context.read<EmergencyRequestState>().goTo(
                EmergencyScreen.emergencyDetails,
              );
            },
          ),
          const SizedBox(height: AppSpacing.space4),
          const _DemoNotice(),
        ],
      ),
    );
  }
}

class _EmergencyDetailsScreen extends StatelessWidget {
  const _EmergencyDetailsScreen();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<EmergencyRequestState>();

    return _FlowFrame(
      emergency: true,
      title: 'Details',
      onBack: () {
        context.read<EmergencyRequestState>().goTo(
          EmergencyScreen.emergencyLocation,
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Tell us only if you can',
            style: Theme.of(context).textTheme.headlineLarge,
          ),
          const SizedBox(height: AppSpacing.space2),
          Text(
            'These details are optional for the demo request.',
            style: Theme.of(context).textTheme.bodyLarge
                ?.copyWith(color: AppColors.muted),
          ),
          const SizedBox(height: AppSpacing.space4),
          Text('WHAT HAPPENED?', style: Theme.of(context).textTheme.labelSmall),
          const SizedBox(height: AppSpacing.space2),
          Wrap(
            spacing: AppSpacing.space2,
            runSpacing: AppSpacing.space2,
            children: ['Cardiac', 'Accident', 'Injury', 'Medical']
                .map(
                  (detail) => _SelectionChip(
                    label: detail,
                    selected: state.selectedDetail == detail,
                    onPressed: () {
                      state.selectDetail(detail);
                    },
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: AppSpacing.space4),
          Text(
            'PEOPLE NEEDING HELP',
            style: Theme.of(context).textTheme.labelSmall,
          ),
          const SizedBox(height: AppSpacing.space2),
          Wrap(
            spacing: AppSpacing.space2,
            runSpacing: AppSpacing.space2,
            children: [1, 2, 3, 4]
                .map(
                  (count) => _SelectionChip(
                    label: count == 4 ? '4+' : '$count',
                    selected: state.peopleNeedingHelp == count,
                    onPressed: () {
                      state.selectPeopleNeedingHelp(count);
                    },
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: AppSpacing.space4),
          const TextField(
            minLines: 3,
            maxLines: 4,
            decoration: InputDecoration(
              labelText: 'Additional details',
              hintText: 'Extra information, if you have time',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: AppSpacing.space5),
          _ActionButton(
            label: 'CONTINUE NOW',
            emergency: true,
            onPressed: () {
              state.goTo(EmergencyScreen.emergencyConfirm);
            },
          ),
        ],
      ),
    );
  }
}

class _EmergencyConfirmScreen extends StatelessWidget {
  const _EmergencyConfirmScreen();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<EmergencyRequestState>();

    return _FlowFrame(
      emergency: true,
      title: 'Confirm request',
      onBack: () {
        state.goTo(EmergencyScreen.emergencyDetails);
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Request ambulance',
            style: Theme.of(context).textTheme.headlineLarge,
          ),
          const SizedBox(height: AppSpacing.space4),
          const _InfoCard(
            title: 'DHA Phase 5, Street 12',
            subtitle: 'Near XYZ Mall, Gate 3',
            icon: Icons.location_on_rounded,
          ),
          const SizedBox(height: AppSpacing.space3),
          _InfoCard(
            title:
                '${state.selectedDetail} · ${state.peopleNeedingHelp == 4 ? '4+' : state.peopleNeedingHelp} person${state.peopleNeedingHelp == 1 ? '' : 's'}',
            subtitle: 'Optional demo details',
            icon: Icons.medical_information_rounded,
          ),
          const SizedBox(height: AppSpacing.space3),
          _InfoCard(
            title: '15-second simulated arrival',
            subtitle: 'The backend receives a real request.',
            icon: Icons.timer_outlined,
          ),
          if(state.errorMessage != null) ...[
            const SizedBox(height: AppSpacing.space4),
            _ErrorNotice(message: state.errorMessage!),
          ],
          const SizedBox(height: AppSpacing.space6),
          _ActionButton(
            label: 'REQUEST NOW',
            emergency: true,
            onPressed: state.requestAmbulance,
          ),
        ],
      ),
    );
  }
}

class _EmergencySearchScreen extends StatelessWidget {
  const _EmergencySearchScreen();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<EmergencyRequestState>();

    return _FlowFrame(
      emergency: true,
      title: 'Finding help',
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 52,
              height: 52,
              child: CircularProgressIndicator(
                color: AppColors.red,
                strokeWidth: 6,
              ),
            ),
            const SizedBox(height: AppSpacing.space5),
            Text(
              'FINDING HELP NOW',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineLarge,
            ),
            const SizedBox(height: AppSpacing.space3),
            Text(
              state.isRequesting
                  ? 'Looking for the nearest available ambulance.'
                  : 'Waiting for the request result.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge
                  ?.copyWith(color: AppColors.muted),
            ),
            const SizedBox(height: AppSpacing.space5),
            const _DemoNotice(),
          ],
        ),
      ),
    );
  }
}

class _EmergencyAssignedScreen extends StatelessWidget {
  const _EmergencyAssignedScreen();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<EmergencyRequestState>();
    final assignment = state.result!.assignedAmbulance!;

    return _FlowFrame(
      emergency: true,
      title: 'Help assigned',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _StatusPill(label: 'Ambulance found', color: AppColors.green),
          const SizedBox(height: AppSpacing.space3),
          Text(
            '${assignment.label} is coming',
            style: Theme.of(context).textTheme.headlineLarge,
          ),
          const SizedBox(height: AppSpacing.space3),
          _InfoCard(
            title: 'City Emergency Services',
            subtitle: '${assignment.distanceKm.toStringAsFixed(2)} km away',
            icon: Icons.local_hospital_rounded,
          ),
          if(state.outcome != null) ...[
            const SizedBox(height: AppSpacing.space3),
            _InfoCard(
              title: 'Dispatch update',
              subtitle: state.outcome!.message,
              icon: Icons.swap_horiz_rounded,
              highlighted: true,
            ),
          ],
          const SizedBox(height: AppSpacing.space4),
          _SimulationRoute(remainingSeconds: state.remainingSeconds),
          const SizedBox(height: AppSpacing.space3),
          Text(
            'Arrival simulation starts now: ${state.remainingSeconds} seconds remaining.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: AppColors.muted),
          ),
          const SizedBox(height: AppSpacing.space4),
          const _DemoNotice(),
        ],
      ),
    );
  }
}

class _EmergencyBusyScreen extends StatelessWidget {
  const _EmergencyBusyScreen();

  @override
  Widget build(BuildContext context) {
    return _FlowFrame(
      emergency: true,
      title: 'No unit available',
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(
              Icons.warning_amber_rounded,
              color: AppColors.orange,
              size: 64,
            ),
            const SizedBox(height: AppSpacing.space4),
            Text(
              'All ambulances are busy',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineLarge,
            ),
            const SizedBox(height: AppSpacing.space3),
            Text(
              'Your request is in the queue. For a real emergency, call 1122 directly.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge
                  ?.copyWith(color: AppColors.muted),
            ),
            const SizedBox(height: AppSpacing.space5),
            _ActionButton(
              label: 'BACK TO HOME',
              onPressed: () {
                context.read<EmergencyRequestState>().reset();
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _EmergencyEnRouteScreen extends StatelessWidget {
  const _EmergencyEnRouteScreen();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<EmergencyRequestState>();
    final assignment = state.result!.assignedAmbulance!;

    return _FlowFrame(
      emergency: true,
      title: 'Ambulance en route',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _StatusPill(label: 'En route', color: AppColors.blue),
          const SizedBox(height: AppSpacing.space3),
          Text(
            '${assignment.label} · City Emergency Services',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: AppSpacing.space4),
          _SimulationRoute(remainingSeconds: state.remainingSeconds),
          const SizedBox(height: AppSpacing.space4),
          Text(
            '${state.remainingSeconds} seconds until arrival',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineMedium
                ?.copyWith(color: AppColors.red),
          ),
          const SizedBox(height: AppSpacing.space4),
          const _DemoNotice(),
        ],
      ),
    );
  }
}

class _EmergencyApproachingScreen extends StatelessWidget {
  const _EmergencyApproachingScreen();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<EmergencyRequestState>();

    return _FlowFrame(
      emergency: true,
      title: 'Ambulance approaching',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.space5),
            decoration: BoxDecoration(
              color: AppColors.red,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Column(
              children: [
                Text(
                  'AMBULANCE APPROACHING',
                  style: Theme.of(context).textTheme.labelLarge
                      ?.copyWith(color: AppColors.surface),
                ),
                const SizedBox(height: AppSpacing.space2),
                Text(
                  'ARRIVING NOW',
                  style: Theme.of(context).textTheme.headlineLarge
                      ?.copyWith(color: AppColors.surface),
                ),
                const SizedBox(height: AppSpacing.space2),
                Text(
                  '${state.remainingSeconds} seconds remaining · be ready at your entrance',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium
                      ?.copyWith(color: AppColors.surface),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.space4),
          _SimulationRoute(remainingSeconds: state.remainingSeconds),
          const SizedBox(height: AppSpacing.space4),
          const _DemoNotice(),
        ],
      ),
    );
  }
}

class _EmergencyArrivedScreen extends StatelessWidget {
  const _EmergencyArrivedScreen();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<EmergencyRequestState>();
    final assignment = state.result!.assignedAmbulance!;

    return _FlowFrame(
      emergency: true,
      title: 'Ambulance arrived',
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(
              Icons.local_hospital_rounded,
              color: AppColors.red,
              size: 64,
            ),
            const SizedBox(height: AppSpacing.space4),
            Text(
              'Ambulance has arrived',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineLarge,
            ),
            const SizedBox(height: AppSpacing.space3),
            Text(
              '${assignment.label} · City Emergency Services',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge
                  ?.copyWith(color: AppColors.muted),
            ),
            const SizedBox(height: AppSpacing.space5),
            if(state.isCompleting)
              const Center(
                child: CircularProgressIndicator(color: AppColors.red),
              )
            else if(state.errorMessage != null)
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _ErrorNotice(message: state.errorMessage!),
                  const SizedBox(height: AppSpacing.space3),
                  _ActionButton(
                    label: 'TRY AGAIN',
                    emergency: true,
                    onPressed: state.retryCompletion,
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _EmergencyCompleteScreen extends StatelessWidget {
  const _EmergencyCompleteScreen();

  @override
  Widget build(BuildContext context) {
    final assignment = context
        .watch<EmergencyRequestState>()
        .result!
        .assignedAmbulance!;

    return _FlowFrame(
      emergency: true,
      title: 'Request complete',
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(
              Icons.check_circle_rounded,
              color: AppColors.green,
              size: 64,
            ),
            const SizedBox(height: AppSpacing.space4),
            Text(
              'Request complete',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineLarge,
            ),
            const SizedBox(height: AppSpacing.space2),
            Text(
              'We hope everything is okay.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge
                  ?.copyWith(color: AppColors.muted),
            ),
            const SizedBox(height: AppSpacing.space5),
            _InfoCard(
              title: assignment.label,
              subtitle: 'City Emergency Services',
              icon: Icons.local_hospital_rounded,
            ),
            const SizedBox(height: AppSpacing.space5),
            _ActionButton(
              label: 'BACK TO HOME',
              onPressed: () {
                context.read<EmergencyRequestState>().reset();
              },
            ),
          ],
        ),
      ),
    );
  }
}

enum _UserTab { home, emergency, services, requests, profile }

class _ProfileScreen extends StatelessWidget {
  const _ProfileScreen();

  @override
  Widget build(BuildContext context) {
    return _FlowFrame(
      title: 'Profile',
      tab: _UserTab.profile,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Align(
            child: CircleAvatar(
              radius: 26,
              backgroundColor: AppColors.blue,
              child: Icon(
                Icons.person,
                color: AppColors.surface,
                size: 24,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.space2),
          Text(
            'Hal Jordan',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: AppSpacing.space5),
          const _ProfileRow(label: 'Saved addresses'),
          const SizedBox(height: AppSpacing.space2),
          const _ProfileRow(label: 'Notification settings'),
          const SizedBox(height: AppSpacing.space2),
          const _ProfileRow(label: 'Language · English'),
          const SizedBox(height: AppSpacing.space2),
          _ProfileRow(
            label: 'Driver portal',
            onPressed: () {
              context.read<EmergencyRequestState>().goTo(
                EmergencyScreen.driverJob,
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ProfileRow extends StatelessWidget {
  const _ProfileRow({required this.label, this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: Container(
          constraints: const BoxConstraints(minHeight: 56),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.space3),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.line),
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ),
              Text(
                '›',
                style: Theme.of(context).textTheme.labelLarge
                    ?.copyWith(color: AppColors.muted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UserTabScreen extends StatelessWidget {
  const _UserTabScreen({required this.title, required this.tab});

  final String title;
  final _UserTab tab;

  @override
  Widget build(BuildContext context) {
    return _FlowFrame(
      title: title,
      tab: tab,
      child: const SizedBox.shrink(),
    );
  }
}

class _UserTabBar extends StatelessWidget {
  const _UserTabBar({required this.current});

  final _UserTab current;

  @override
  Widget build(BuildContext context) {
    return NavigationBarTheme(
      data: NavigationBarThemeData(
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? AppColors.blue : AppColors.ink,
          );
        }),
      ),
      child: NavigationBar(
      height: 60,
      backgroundColor: AppColors.surface,
      indicatorColor: AppColors.surface,
      selectedIndex: current.index,
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return TextStyle(
          fontSize: 11,
          fontWeight: selected ? FontWeight.w800 : FontWeight.w400,
          color: selected ? AppColors.blue : AppColors.muted,
        );
      }),
      onDestinationSelected: (index) {
        final state = context.read<EmergencyRequestState>();
        switch(_UserTab.values[index]) {
          case _UserTab.home:
            state.goTo(EmergencyScreen.home);
          case _UserTab.emergency:
            state.goTo(EmergencyScreen.emergencyType);
          case _UserTab.services:
            state.goTo(EmergencyScreen.services);
          case _UserTab.requests:
            state.goTo(EmergencyScreen.requests);
          case _UserTab.profile:
            state.goTo(EmergencyScreen.profile);
        }
      },
      destinations: const [
        NavigationDestination(icon: Icon(Icons.home_outlined), label: 'Home'),
        NavigationDestination(icon: Icon(Icons.add), label: 'Emergency'),
        NavigationDestination(icon: Icon(Icons.search), label: 'Services'),
        NavigationDestination(
          icon: Icon(Icons.grid_view_outlined),
          label: 'Requests',
        ),
        NavigationDestination(
          icon: Icon(Icons.circle_outlined),
          label: 'Profile',
        ),
      ],
      ),
    );
  }
}

class _FlowFrame extends StatelessWidget {
  const _FlowFrame({
    required this.child,
    this.title,
    this.onBack,
    this.emergency = false,
    this.tab,
  });

  final Widget child;
  final String? title;
  final VoidCallback? onBack;
  final bool emergency;
  final _UserTab? tab;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.soft,
      bottomNavigationBar: tab == null ? null : _UserTabBar(current: tab!),
      body: SafeArea(
        child: Column(
          children: [
            if(emergency)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  vertical: AppSpacing.space2,
                ),
                color: AppColors.red,
                child: Text(
                  'EMERGENCY MODE',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.labelSmall
                      ?.copyWith(color: AppColors.surface),
                ),
              ),
            if(title != null)
              SizedBox(
                height: 56,
                child: Row(
                  children: [
                    if(onBack != null)
                      IconButton(
                        icon: const Icon(Icons.arrow_back_rounded),
                        onPressed: onBack,
                        tooltip: 'Back',
                      )
                    else
                      const SizedBox(width: 48),
                    Expanded(
                      child: Text(
                        title!,
                        textAlign: onBack == null
                            ? TextAlign.center
                            : TextAlign.left,
                        style: Theme.of(context).textTheme.labelLarge
                            ?.copyWith(color: AppColors.blue),
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
              ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.space4),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 620),
                  child: child,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.onPressed,
    this.emergency = false,
    this.color,
  });

  final String label;
  final VoidCallback onPressed;
  final bool emergency;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final backgroundColor = color ?? (emergency ? AppColors.red : AppColors.blue);

    return SizedBox(
      height: emergency ? 56 : 48,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: AppColors.surface,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
        ),
        child: Text(label),
      ),
    );
  }
}

class _ChoiceCard extends StatelessWidget {
  const _ChoiceCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.md),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 88),
          padding: const EdgeInsets.all(AppSpacing.space4),
          decoration: BoxDecoration(
            border: Border.all(color: color, width: 2),
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Row(
            children: [
              Icon(icon, color: color, size: 34),
              const SizedBox(width: AppSpacing.space3),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: AppSpacing.space1),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodyMedium
                          ?.copyWith(color: AppColors.muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    this.highlighted = false,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.space4),
      decoration: BoxDecoration(
        color: highlighted ? AppColors.soft : AppColors.surface,
        border: Border.all(color: highlighted ? AppColors.red : AppColors.line),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        children: [
          Icon(icon, color: highlighted ? AppColors.red : AppColors.blue),
          const SizedBox(width: AppSpacing.space3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: AppSpacing.space1),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodyMedium
                      ?.copyWith(color: AppColors.muted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SelectionChip extends StatelessWidget {
  const _SelectionChip({
    required this.label,
    required this.selected,
    required this.onPressed,
  });

  final String label;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) {
        onPressed();
      },
      selectedColor: AppColors.blue,
      labelStyle: TextStyle(
        color: selected ? AppColors.surface : AppColors.ink,
        fontWeight: FontWeight.w700,
      ),
      side: BorderSide(color: selected ? AppColors.blue : AppColors.line),
    );
  }
}

class _SimulationRoute extends StatelessWidget {
  const _SimulationRoute({required this.remainingSeconds});

  final int remainingSeconds;

  @override
  Widget build(BuildContext context) {
    final progress = (15 - remainingSeconds).clamp(0, 15) / 15;

    return Container(
      height: 190,
      decoration: BoxDecoration(
        color: AppColors.page,
        border: Border.all(color: AppColors.line, width: 2),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Stack(
            children: [
              Center(
                child: Container(
                  width: constraints.maxWidth * .55,
                  height: 3,
                  color: AppColors.line,
                ),
              ),
              const Positioned(
                left: AppSpacing.space3,
                top: AppSpacing.space3,
                child: Text('City Emergency Services'),
              ),
              const Positioned(
                right: AppSpacing.space3,
                bottom: AppSpacing.space3,
                child: Text('Pickup point'),
              ),
              AnimatedPositioned(
                duration: const Duration(milliseconds: 700),
                curve: Curves.easeInOut,
                left: constraints.maxWidth * (.12 + (.48 * progress)),
                top: constraints.maxHeight * (.20 + (.43 * progress)),
                child: const _RouteMarker(
                  color: AppColors.red,
                  icon: Icons.local_hospital_rounded,
                ),
              ),
              Positioned(
                right: constraints.maxWidth * .10,
                bottom: constraints.maxHeight * .13,
                child: const _RouteMarker(
                  color: AppColors.blue,
                  icon: Icons.person_pin_circle_rounded,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _RouteMarker extends StatelessWidget {
  const _RouteMarker({required this.color, required this.icon});

  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: color,
        border: Border.all(color: AppColors.surface, width: 3),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Icon(icon, color: AppColors.surface),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.space3,
          vertical: AppSpacing.space2,
        ),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(99),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelSmall
              ?.copyWith(color: AppColors.surface),
        ),
      ),
    );
  }
}

class _DemoNotice extends StatelessWidget {
  const _DemoNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.space3),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.red),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Text(
        'Simulation mode only. For a real emergency, call 1122.',
        style: Theme.of(context).textTheme.bodyMedium
            ?.copyWith(color: AppColors.red, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _ErrorNotice extends StatelessWidget {
  const _ErrorNotice({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.space3),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.red),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Text(
        message,
        style: Theme.of(context).textTheme.bodyMedium
            ?.copyWith(color: AppColors.red, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _OtpBox extends StatelessWidget {
  const _OtpBox();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      height: 56,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Text('•', style: Theme.of(context).textTheme.headlineSmall),
    );
  }
}
