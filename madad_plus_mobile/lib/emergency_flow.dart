import 'dart:io';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:record/record.dart';

import 'services/emergency_request_state.dart';
import 'services/emergency_service.dart';
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
        return const _ServicesScreen();
      case EmergencyScreen.requests:
        return const _RequestsScreen();
      case EmergencyScreen.profile:
        return const _ProfileScreen();
      case EmergencyScreen.tradeDetail:
        return const _TradeDetailScreen();
      case EmergencyScreen.serviceDescription:
        return const _ServiceDescriptionScreen();
      case EmergencyScreen.serviceLocation:
        return const _ServiceLocationScreen();
      case EmergencyScreen.serviceSchedule:
        return const _ServiceScheduleScreen();
      case EmergencyScreen.serviceConfirm:
        return const _ServiceConfirmScreen();
      case EmergencyScreen.domesticJob:
        return const _DomesticJobScreen();
      case EmergencyScreen.costReview:
        return const _CostReviewScreen();
      case EmergencyScreen.providerDashboard:
        return const _ProviderDashboardScreen();
      case EmergencyScreen.providerRequest:
        return const _ProviderRequestScreen();
      case EmergencyScreen.providerAccepted:
        return const _ProviderAcceptedScreen();
      case EmergencyScreen.providerJob:
        return const _ProviderJobScreen();
      case EmergencyScreen.home:
        return const _HomeScreen();
      case EmergencyScreen.homeLocation:
        return const _HomeLocationScreen();
      case EmergencyScreen.emergencyType:
        return const _EmergencyTypeScreen();
      case EmergencyScreen.emergencyLocation:
        return const _EmergencyLocationScreen();
      case EmergencyScreen.emergencySpeak:
        return const _EmergencySpeakScreen();
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

TextStyle? _largeTitle(BuildContext context) {
  return Theme.of(context).textTheme.headlineLarge?.copyWith(
    height: 1.08,
    letterSpacing: -0.6,
  );
}

InputDecoration _emergencyField({required String label, String? hint}) {
  const radius = BorderRadius.all(Radius.circular(12));
  const border = OutlineInputBorder(
    borderRadius: radius,
    borderSide: BorderSide(color: AppColors.line),
  );
  return InputDecoration(
    labelText: label,
    hintText: hint,
    filled: true,
    fillColor: Color(0xFFFFF1F2),
    border: border,
    enabledBorder: border,
    focusedBorder: const OutlineInputBorder(
      borderRadius: radius,
      borderSide: BorderSide(color: AppColors.red, width: 2),
    ),
  );
}

TextStyle? _sectionTitle(BuildContext context) {
  return Theme.of(context).textTheme.headlineMedium?.copyWith(
    height: 1.15,
    letterSpacing: -0.4,
  );
}

Text _providerSectionLabel(BuildContext context, String label) {
  return Text(
    label,
    style: Theme.of(context).textTheme.labelSmall?.copyWith(
      letterSpacing: 0.6,
      fontWeight: FontWeight.w600,
    ),
  );
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return _FlowFrame(
      plainChrome: true,
      fill: true,
      child: _SoftArrive(
        child: Transform.translate(
          offset: const Offset(0, -70),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _MarkPlate(
              icon: Icons.health_and_safety_rounded,
              color: AppColors.red,
              alignment: Alignment.center,
            ),
            const SizedBox(height: AppSpacing.space5),
            Text(
              'Madad+',
              textAlign: TextAlign.center,
              style: _largeTitle(context),
            ),
            const SizedBox(height: AppSpacing.space2),
            Text(
              'Emergency help and trusted local services.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: AppColors.muted,
                height: 1.45,
              ),
            ),
            const SizedBox(height: AppSpacing.space6),
            _PressScale(
              child: _ActionButton(
                label: 'GET STARTED',
                onPressed: () {
                  context.read<EmergencyRequestState>().goTo(
                    EmergencyScreen.onboarding,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    )
    );
  }
}

class _OnboardingScreen extends StatelessWidget {
  const _OnboardingScreen();

  @override
  Widget build(BuildContext context) {
    return _FlowFrame(
      plainChrome: true,
      fill: true,
      title: 'Welcome',
      onBack: () {
        context.read<EmergencyRequestState>().goTo(EmergencyScreen.splash);
      },
      child: _SoftArrive(
        child: Transform.translate(
          offset: const Offset(0, -90),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _MarkPlate(
              icon: Icons.support_agent_rounded,
              color: AppColors.ink,
            ),
            const SizedBox(height: AppSpacing.space5),
            Text('Help when you need it', style: _largeTitle(context)),
            const SizedBox(height: AppSpacing.space3),
            Text(
              'Request emergency help or find a trusted local service provider.',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: AppColors.muted,
                height: 1.45,
              ),
            ),
            const SizedBox(height: AppSpacing.space6),
            _PressScale(
              child: _ActionButton(
                label: 'CONTINUE',
                onPressed: () {
                  context.read<EmergencyRequestState>().goTo(
                    EmergencyScreen.login,
                  );
                },
              ),
            ),
          ],
        ),
      ),
      )
    );
  }
}

class _LoginScreen extends StatelessWidget {
  const _LoginScreen();

  @override
  Widget build(BuildContext context) {
    final state = context.read<EmergencyRequestState>();
    return _FlowFrame(
      plainChrome: true,
      title: 'Sign in',
      onBack: () {
        state.goTo(EmergencyScreen.onboarding);
      },
      child: _SoftArrive(
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Existing account', style: _sectionTitle(context)),
          const SizedBox(height: AppSpacing.space2),
          Text(
            'We will send a verification code. Demo mode does not send a real SMS.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: AppColors.muted,
              height: 1.45,
            ),
          ),
          const SizedBox(height: AppSpacing.space5),
          const TextField(
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              labelText: 'Phone number',
              hintText: '+92 300 1234567',
              filled: true,
              fillColor: AppColors.surface,
              contentPadding: EdgeInsets.symmetric(
                horizontal: AppSpacing.space4,
                vertical: AppSpacing.space4,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(14)),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(14)),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(14)),
                borderSide: BorderSide(color: AppColors.focus, width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.space5),
          _PressScale(
            child: _ActionButton(
              label: 'CONTINUE',
              onPressed: state.continueSignIn,
            ),
          ),
          const SizedBox(height: AppSpacing.space4),
          _GroupedLinks(
            links: [
              _GroupedLink('Sign in as driver', state.continueDriverSignIn),
              _GroupedLink('Sign in as provider', state.continueProviderSignIn),
              _GroupedLink(
                'Create account',
                () {
                  state.goTo(EmergencyScreen.roleChoice);
                },
              ),
            ],
          ),
        ],
        ),
      ),
    );
  }
}

class _OtpScreen extends StatelessWidget {
  const _OtpScreen();

  @override
  Widget build(BuildContext context) {
    return _FlowFrame(
      plainChrome: true,
      title: 'Verify phone',
      onBack: () {
        context.read<EmergencyRequestState>().backFromOtp();
      },
      child: _SoftArrive(
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Enter verification code', style: _sectionTitle(context)),
          const SizedBox(height: AppSpacing.space2),
          Text(
            'Demo mode: tap verify to continue.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: AppColors.muted,
              height: 1.45,
            ),
          ),
          const SizedBox(height: AppSpacing.space5),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [_OtpBox(), _OtpBox(), _OtpBox(), _OtpBox()],
          ),
          const SizedBox(height: AppSpacing.space5),
          _PressScale(
            child: _ActionButton(
              label: 'VERIFY',
              onPressed: () {
                context.read<EmergencyRequestState>().verifyCode();
              },
            ),
          ),
        ],
        ),
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
          const SizedBox(height: AppSpacing.space3),
          _ActionButton(
            label: 'Register as Provider',
            onPressed: () {
              context.read<EmergencyRequestState>().chooseAccount(
                AccountPath.provider,
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
    final state = context.watch<EmergencyRequestState>();
    final driver = state.accountPath == AccountPath.driver;
    final provider = state.accountPath == AccountPath.provider;
    final title = switch(state.accountPath) {
      AccountPath.driver => 'Register as Driver',
      AccountPath.provider => 'Register as Provider',
      AccountPath.signIn || AccountPath.user => 'Register as User',
    };

    return _FlowFrame(
      title: title,
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
          if(provider) ...[
            const SizedBox(height: AppSpacing.space4),
            Text('TRADE', style: Theme.of(context).textTheme.labelSmall),
            const SizedBox(height: AppSpacing.space2),
            Wrap(
              spacing: AppSpacing.space2,
              runSpacing: AppSpacing.space2,
              children: ['Carpenter', 'Plumber', 'Electrician']
                  .map(
                    (trade) => _SelectionChip(
                      label: trade,
                      selected: state.registerTrade == trade,
                      onPressed: () {
                        state.selectRegisterTrade(trade);
                      },
                    ),
                  )
                  .toList(),
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

const _pickupStatuses = {'ASSIGNED', 'EN_ROUTE', 'TRANSFER_EN_ROUTE'};
const _hospitalStatuses = {'PICKED_UP', 'EN_ROUTE_HOSPITAL'};

String _peopleLabel(int? count) {
  if(count == null) {
    return 'people count not sent';
  }
  if(count >= 4) {
    return '4+ people';
  }
  return count == 1 ? '1 person' : '$count people';
}

class _DriverJobScreen extends StatefulWidget {
  const _DriverJobScreen();

  @override
  State<_DriverJobScreen> createState() => _DriverJobScreenState();
}

class _DriverJobScreenState extends State<_DriverJobScreen> {
  double slide = 0;
  bool dropoffSending = false;

  Future<void> slideTo(EmergencyRequestState state, double value) async {
    setState(() {
      slide = value;
    });
    if(value < 1 || dropoffSending) {
      return;
    }

    dropoffSending = true;
    final sent = await state.sendDriverUpdate('dropoff');
    if(!mounted) {
      return;
    }
    setState(() {
      slide = 0;
      dropoffSending = false;
    });
    if(!sent) {
      return;
    }

    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Patient dropped off'),
          content: const Text('This ambulance is free again.'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  Future<void> confirmUnavailable(EmergencyRequestState state) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Mark this ambulance unavailable?'),
          content: const Text(
            'This ambulance becomes unavailable and the nearest free ambulance takes this call.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              child: const Text('Mark as unavailable'),
            ),
          ],
        );
      },
    );
    if(confirmed != true || !mounted) {
      return;
    }

    await state.reassignDriverRequest();
  }

  Widget pickAmbulance(BuildContext context, EmergencyRequestState state) {
    return _FlowFrame(
      title: 'Choose your ambulance',
      onBack: () {
        state.goTo(EmergencyScreen.login);
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Which ambulance are you driving?',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: AppSpacing.space2),
          Text(
            'Calls for that ambulance will show up here.',
            style: Theme.of(context).textTheme.bodyLarge
                ?.copyWith(color: AppColors.muted),
          ),
          const SizedBox(height: AppSpacing.space4),
          if(state.driverLoading)
            const Center(child: CircularProgressIndicator()),
          if(state.driverError != null) ...[
            _ErrorNotice(message: state.driverError!),
            const SizedBox(height: AppSpacing.space3),
            _SecondaryButton(
              label: 'Try again',
              onPressed: state.loadDriverAmbulances,
            ),
            const SizedBox(height: AppSpacing.space3),
          ],
          for(final ambulance in state.driverAmbulances) ...[
            _ProfileRow(
              label: '${ambulance.label} · ${ambulance.driverName ?? 'No driver'}',
              trailing: ambulance.status,
              onPressed: () {
                state.chooseDriverAmbulance(ambulance);
              },
            ),
            const SizedBox(height: AppSpacing.space2),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<EmergencyRequestState>();
    if(state.driverId == null) {
      return pickAmbulance(context, state);
    }

    final call = state.driverCall;
    final atPickup = _pickupStatuses.contains(call?.status);
    final toHospital = _hospitalStatuses.contains(call?.status);
    final atDropoff = call?.status == 'ARRIVED';
    final String title;
    if(call == null) {
      title = 'No active call';
    }
    else if(atPickup) {
      title = 'Pickup';
    }
    else if(toHospital) {
      title = 'To hospital';
    }
    else if(atDropoff) {
      title = 'Drop-off';
    }
    else {
      title = 'Active call';
    }
    final status = state.driverAmbulanceStatus ?? 'UNKNOWN';
    final statusColor = switch(status) {
      'BUSY' => AppColors.blue,
      'FREE' => AppColors.green,
      _ => AppColors.orange,
    };
    final busy = state.driverLoading;

    return _FlowFrame(
      title: title,
      onBack: () {
        state.goTo(EmergencyScreen.login);
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _TripMap(),
          const SizedBox(height: AppSpacing.space3),
          Text(
            state.driverAmbulanceLabel ?? 'Ambulance',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: AppSpacing.space2),
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
          if(call == null)
            Text(
              'No call on this ambulance.',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          if(call != null && !toHospital && !atDropoff) ...[
            Text(
              call.pickupAddress ?? 'The caller did not send an address.',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            Text(
              '${call.emergencyDescription ?? 'Emergency'} · ${_peopleLabel(call.peopleCount)}',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            if((call.additionalDetails?.trim() ?? '').isNotEmpty)
              Text(
                call.additionalDetails!.trim(),
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            Text(
              call.callerPhone == null
                  ? 'No caller phone was sent.'
                  : 'Caller ${call.callerPhone}',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ],
          if(call != null && (toHospital || atDropoff)) ...[
            Text(
              call.hospitalName ?? 'Hospital',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            Text(
              call.hospitalAddress ?? 'The server did not attach a hospital address.',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            Text(
              'Patient is on board · ${call.emergencyDescription ?? 'Emergency'}',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ],
          if(state.driverError != null) ...[
            const SizedBox(height: AppSpacing.space4),
            _ErrorNotice(message: state.driverError!),
          ],
          const SizedBox(height: AppSpacing.space5),
          if(atPickup)
            _ActionButton(
              label: 'Picked up',
              onPressed: busy
                  ? null
                  : () {
                      state.sendDriverUpdate('pickup');
                    },
            ),
          if(toHospital)
            _ActionButton(
              label: 'Reached the hospital',
              onPressed: busy
                  ? null
                  : () {
                      state.sendDriverUpdate('hospital');
                    },
            ),
          if(atDropoff) ...[
            Text(
              'Dropped off',
              style: Theme.of(context).textTheme.labelSmall,
            ),
            Slider(
              value: slide,
              label: 'Dropped off',
              onChanged: busy
                  ? null
                  : (value) {
                      slideTo(state, value);
                    },
            ),
            Text(
              'Slide to the end to confirm.',
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: AppColors.muted),
            ),
          ],
          if(call == null && status == 'FREE')
            _SecondaryButton(
              label: 'Mark as unavailable',
              onPressed: state.markDriverUnavailable,
            ),
          if(call == null && status == 'UNAVAILABLE')
            _SecondaryButton(
              label: 'Mark as available',
              onPressed: state.markDriverAvailable,
            ),
          if(atPickup || toHospital) ...[
            const SizedBox(height: AppSpacing.space3),
            _SecondaryButton(
              label: 'Mark as unavailable',
              onPressed: busy
                  ? null
                  : () {
                      confirmUnavailable(state);
                    },
            ),
          ],
          const SizedBox(height: AppSpacing.space3),
          _SecondaryButton(
            label: 'Refresh',
            onPressed: state.loadDriverPortal,
          ),
          const SizedBox(height: AppSpacing.space3),
          _SecondaryButton(
            label: 'Change ambulance',
            onPressed: state.changeDriverAmbulance,
          ),
        ],
      ),
    );
  }
}

class _HomeScreen extends StatelessWidget {
  const _HomeScreen();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<EmergencyRequestState>();
    return _FlowFrame(
      plainChrome: true,
      title: state.homeTitle,
      onTitle: () {
        state.goTo(EmergencyScreen.homeLocation);
      },
      tab: _UserTab.home,
      child: _SoftArrive(
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('How can we help?', style: _largeTitle(context)),
          const SizedBox(height: AppSpacing.space4),
          _PressScale(
            child: _ChoiceCard(
              quiet: true,
              emphasis: true,
              icon: Icons.emergency_rounded,
              title: 'Emergency help',
              subtitle: 'Request an ambulance for a medical emergency.',
              color: AppColors.red,
              onTap: () {
                state.goTo(EmergencyScreen.emergencyType);
              },
            ),
          ),
          const SizedBox(height: AppSpacing.space5),
          _PressScale(
            child: _ChoiceCard(
              quiet: true,
              icon: Icons.search,
              title: 'Find a service provider',
              subtitle:
                  'Plumber, electrician, AC technician, mechanic, and more',
              color: AppColors.green,
              onTap: () {
                state.goTo(EmergencyScreen.services);
              },
            ),
          ),
          const SizedBox(height: AppSpacing.space5),
          Text(
            'Simulation mode only. For a real emergency, call 1122.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.muted,
              height: 1.45,
            ),
          ),
        ],
        ),
      ),
    );
  }
}

class _HomeLocationScreen extends StatefulWidget {
  const _HomeLocationScreen();

  @override
  State<_HomeLocationScreen> createState() => _HomeLocationScreenState();
}

class _HomeLocationScreenState extends State<_HomeLocationScreen> {
  final _addressController = TextEditingController();
  var _busy = false;
  String? _message;

  @override
  void dispose() {
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _saveTyped() async {
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final state = context.read<EmergencyRequestState>();
      final place = await state.lookupAddress(_addressController.text);
      if(!mounted) {
        return;
      }
      if(place == null) {
        setState(() {
          _message = 'That address was not found.';
        });
        return;
      }
      await state.saveHomePlace(
        address: place.address,
        latitude: place.latitude,
        longitude: place.longitude,
      );
      state.goTo(EmergencyScreen.home);
    } catch (_) {
      if(!mounted) {
        return;
      }
      setState(() {
        _message = 'The address lookup did not finish. Try again.';
      });
    } finally {
      if(mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  Future<void> _saveDevice() async {
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final state = context.read<EmergencyRequestState>();
      final place = await state.locateDevice();
      if(!mounted) {
        return;
      }
      if(place == null) {
        setState(() {
          _message = state.locationProblem;
        });
        return;
      }
      await state.saveHomePlace(
        address: place.address,
        latitude: place.latitude,
        longitude: place.longitude,
      );
      state.goTo(EmergencyScreen.home);
    } catch (_) {
      if(!mounted) {
        return;
      }
      setState(() {
        _message = 'Your location could not be read. Type the address instead.';
      });
    } finally {
      if(mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<EmergencyRequestState>();
    return _FlowFrame(
      plainChrome: true,
      title: 'Your location',
      onBack: () {
        state.goTo(EmergencyScreen.home);
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Where are you?', style: _sectionTitle(context)),
          const SizedBox(height: AppSpacing.space4),
          _ActionButton(
            label: 'Find my location',
            onPressed: _busy ? null : _saveDevice,
          ),
          const SizedBox(height: AppSpacing.space4),
          TextField(
            controller: _addressController,
            decoration: const InputDecoration(
              labelText: 'Address',
              border: OutlineInputBorder(),
            ),
            textInputAction: TextInputAction.done,
            onSubmitted: (_) {
              if(!_busy) {
                _saveTyped();
              }
            },
          ),
          const SizedBox(height: AppSpacing.space3),
          _SecondaryButton(
            label: 'Use this address',
            onPressed: _busy ? null : _saveTyped,
          ),
          if(_message != null) ...[
            const SizedBox(height: AppSpacing.space4),
            _ErrorNotice(message: _message!),
          ],
          const SizedBox(height: AppSpacing.space5),
          _providerSectionLabel(context, 'SAVED LOCATIONS'),
          const SizedBox(height: AppSpacing.space2),
          if(state.homePlaces.isEmpty)
            Text(
              'No saved locations yet.',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: AppColors.muted,
                height: 1.4,
              ),
            )
          else
            _InsetGroup(
              children: [
                for(final place in state.homePlaces)
                  _InsetRow(
                    label: place.address,
                    onPressed: () {
                      state.selectHomePlace(place);
                      state.goTo(EmergencyScreen.home);
                    },
                  ),
              ],
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
      plainChrome: true,
      title: 'Emergency help',
      tab: _UserTab.emergency,
      onBack: () {
        context.read<EmergencyRequestState>().goTo(EmergencyScreen.home);
      },
      child: _SoftArrive(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('What do you need?', style: _largeTitle(context)),
            const SizedBox(height: AppSpacing.space2),
            Text(
              'Ambulance requests are available in this demo.',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: AppColors.muted,
                height: 1.45,
              ),
            ),
            const SizedBox(height: AppSpacing.space4),
            _PressScale(
              child: _ChoiceCard(
                quiet: true,
                emphasis: true,
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
            ),
            const SizedBox(height: AppSpacing.space5),
            Text(
              'Simulation mode only. For a real emergency, call 1122.',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: AppColors.red,
                height: 1.45,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmergencyLocationScreen extends StatefulWidget {
  const _EmergencyLocationScreen();

  @override
  State<_EmergencyLocationScreen> createState() =>
      _EmergencyLocationScreenState();
}

class _EmergencyLocationScreenState extends State<_EmergencyLocationScreen> {
  static const _openCenter = LatLng(24.8600, 67.0100);
  final _mapController = MapController();
  final _addressController = TextEditingController();
  var _busy = false;
  String? _message;

  @override
  void dispose() {
    _mapController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  void _useHomeLocation() {
    final state = context.read<EmergencyRequestState>();
    final latitude = state.homeLatitude;
    final longitude = state.homeLongitude;
    final address = state.homeAddress;
    if(latitude == null || longitude == null || address == null) {
      setState(() {
        _message = 'Set a location from the home address first.';
      });
      return;
    }
    _dropPin(state, latitude: latitude, longitude: longitude, address: address);
  }

  Future<void> _useDeviceLocation() async {
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final state = context.read<EmergencyRequestState>();
      final place = await state.locateDevice();
      if(!mounted) {
        return;
      }
      if(place == null) {
        setState(() {
          _message = state.locationProblem;
        });
        return;
      }
      _dropPin(
        state,
        latitude: place.latitude,
        longitude: place.longitude,
        address: place.address,
      );
    } catch (_) {
      if(!mounted) {
        return;
      }
      setState(() {
        _message = 'Your location could not be read. Type the address instead.';
      });
    } finally {
      if(mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  Future<void> _lookupAddress() async {
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final state = context.read<EmergencyRequestState>();
      final place = await state.lookupAddress(_addressController.text);
      if(!mounted) {
        return;
      }
      if(place == null) {
        setState(() {
          _message = 'That address was not found.';
        });
        return;
      }
      _dropPin(
        state,
        latitude: place.latitude,
        longitude: place.longitude,
        address: place.address,
      );
    } catch (_) {
      if(!mounted) {
        return;
      }
      setState(() {
        _message = 'The address lookup did not finish. Try again.';
      });
    } finally {
      if(mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  void _dropPin(
    EmergencyRequestState state, {
    required double latitude,
    required double longitude,
    required String address,
  }) {
    state.setEmergencyPin(
      latitude: latitude,
      longitude: longitude,
      address: address,
    );
    _mapController.move(LatLng(latitude, longitude), 16);
    setState(() {
      _message = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<EmergencyRequestState>();
    final pin = state.pinLatitude == null || state.pinLongitude == null
        ? null
        : LatLng(state.pinLatitude!, state.pinLongitude!);

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
            style: _largeTitle(context),
          ),
          const SizedBox(height: AppSpacing.space4),
          Container(
            height: 220,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.red, width: 2),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: pin ?? _openCenter,
                initialZoom: pin == null ? 12 : 16,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.madadplus.madad_plus_mobile',
                  tileProvider: Platform.environment['FLUTTER_TEST'] == 'true'
                      ? _TestTileProvider()
                      : NetworkTileProvider(),
                ),
                if(pin != null)
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: pin,
                        width: 40,
                        height: 40,
                        child: const Icon(
                          Icons.location_on,
                          color: AppColors.red,
                          size: 40,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
            ),
          ),
          const SizedBox(height: AppSpacing.space4),
          _PressScale(
            child: _ActionButton(
              label: 'Find my location',
              emergency: true,
              onPressed: _busy ? null : _useDeviceLocation,
            ),
          ),
          const SizedBox(height: AppSpacing.space3),
          _PressScale(
            child: _SecondaryButton(
              label: 'Use my current location',
              onPressed: _busy ? null : _useHomeLocation,
            ),
          ),
          const SizedBox(height: AppSpacing.space4),
          TextField(
            controller: _addressController,
            decoration: _emergencyField(label: 'Address'),
            textInputAction: TextInputAction.search,
            onSubmitted: (_) {
              if(!_busy) {
                _lookupAddress();
              }
            },
          ),
          const SizedBox(height: AppSpacing.space3),
          _PressScale(
            child: _ActionButton(
              label: 'Show on map',
              onPressed: _busy ? null : _lookupAddress,
            ),
          ),
          if(_message != null) ...[
            const SizedBox(height: AppSpacing.space4),
            _ErrorNotice(message: _message!),
          ],
          const SizedBox(height: AppSpacing.space5),
          _PressScale(
            child: _ActionButton(
              label: 'CONTINUE',
              emergency: true,
              onPressed: pin == null
                  ? null
                  : () {
                      state.goTo(EmergencyScreen.emergencySpeak);
                    },
            ),
          ),
        ],
      ),
    );
  }
}

class _TestTileProvider extends TileProvider {
  static final Uint8List _pixel = Uint8List.fromList(const [
    0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
    0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
    0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
    0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
    0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
    0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
  ]);

  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) {
    return MemoryImage(_pixel);
  }
}

class _EmergencySpeakScreen extends StatefulWidget {
  const _EmergencySpeakScreen();

  @override
  State<_EmergencySpeakScreen> createState() => _EmergencySpeakScreenState();
}

class _EmergencySpeakScreenState extends State<_EmergencySpeakScreen> {
  AudioRecorder? _recorder;
  var _recording = false;
  var _sending = false;

  @override
  void dispose() {
    _recorder?.dispose();
    super.dispose();
  }

  Future<void> _toggleRecording() async {
    final state = context.read<EmergencyRequestState>();
    if(EmergencyRequestState.geminiApiKey.isEmpty) {
      state.typeDetailsInstead();
      return;
    }
    if(_sending) {
      return;
    }

    try {
      if(_recording) {
        final path = await _recorder?.stop();
        setState(() {
          _recording = false;
          _sending = true;
        });
        if(path == null) {
          if(mounted) {
            context.read<EmergencyRequestState>().typeDetailsInstead();
          }
          return;
        }
        final bytes = await File(path).readAsBytes();
        if(!mounted) {
          return;
        }
        await context.read<EmergencyRequestState>().submitSpeech(bytes);
        return;
      }

      final recorder = _recorder ?? AudioRecorder();
      _recorder = recorder;
      final allowed = await recorder.hasPermission();
      if(!allowed) {
        if(mounted) {
          context.read<EmergencyRequestState>().typeDetailsInstead();
        }
        return;
      }
      await recorder.start(
        const RecordConfig(),
        path: '${Directory.systemTemp.path}${Platform.pathSeparator}madad-emergency.m4a',
      );
      if(!mounted) {
        return;
      }
      setState(() {
        _recording = true;
      });
    } catch (_) {
      if(mounted) {
        context.read<EmergencyRequestState>().typeDetailsInstead();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return _FlowFrame(
      emergency: true,
      title: 'What happened',
      onBack: () {
        context.read<EmergencyRequestState>().goTo(
          EmergencyScreen.emergencyLocation,
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Speak in English or Urdu',
            style: _largeTitle(context),
          ),
          const SizedBox(height: AppSpacing.space2),
          Text(
            'Say what happened and how many people need help.',
            style: Theme.of(context).textTheme.bodyLarge
                ?.copyWith(color: AppColors.muted),
          ),
          const SizedBox(height: AppSpacing.space6),
          Center(
            child: _PressScale(
              child: _RecordCircle(
                recording: _recording,
                onPressed: _sending ? null : _toggleRecording,
              ),
            ),
          ),
          if(_sending) ...[
            const SizedBox(height: AppSpacing.space4),
            Text(
              'Sending the recording.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge
                  ?.copyWith(color: AppColors.muted),
            ),
          ],
          const SizedBox(height: AppSpacing.space6),
          _PressScale(
            child: _ActionButton(
              label: 'Type the details instead',
              onPressed: _sending
                  ? null
                  : () {
                      context.read<EmergencyRequestState>().typeDetailsInstead();
                    },
            ),
          ),
        ],
      ),
    );
  }
}

class _RecordCircle extends StatelessWidget {
  const _RecordCircle({required this.recording, required this.onPressed});

  final bool recording;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final color = onPressed == null ? AppColors.line : AppColors.red;

    return Semantics(
      button: true,
      enabled: onPressed != null,
      label: recording ? 'Stop and send' : 'Record',
      excludeSemantics: true,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: Container(
          width: 148,
          height: 148,
          padding: const EdgeInsets.all(AppSpacing.space2),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 8),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.28),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(shape: BoxShape.circle, color: color),
            child: Center(
              child: recording
                  ? Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                    )
                  : Text(
                      'Record',
                      style: Theme.of(context).textTheme.labelLarge
                          ?.copyWith(color: AppColors.surface),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EmergencyDetailsScreen extends StatefulWidget {
  const _EmergencyDetailsScreen();

  @override
  State<_EmergencyDetailsScreen> createState() =>
      _EmergencyDetailsScreenState();
}

class _EmergencyDetailsScreenState extends State<_EmergencyDetailsScreen> {
  late final TextEditingController _detailsController;

  @override
  void initState() {
    super.initState();
    final state = context.read<EmergencyRequestState>();
    _detailsController = TextEditingController(
      text: state.additionalDetails ?? '',
    );
    final notice = state.takeDetailsNotice();
    if(notice != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if(!mounted) {
          return;
        }
        showDialog<void>(
          context: context,
          builder: (dialogContext) {
            return AlertDialog(
              content: Text(notice),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                  },
                  child: const Text('OK'),
                ),
              ],
            );
          },
        );
      });
    }
  }

  @override
  void dispose() {
    _detailsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<EmergencyRequestState>();
    final ready = state.selectedDetail != null && state.peopleNeedingHelp != null;

    return _FlowFrame(
      emergency: true,
      title: 'Details',
      onBack: () {
        context.read<EmergencyRequestState>().goTo(
          EmergencyScreen.emergencySpeak,
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Tell us only if you can',
            style: _largeTitle(context),
          ),
          const SizedBox(height: AppSpacing.space2),
          Text(
            'What happened and how many people need help are required.',
            style: Theme.of(context).textTheme.bodyLarge
                ?.copyWith(color: AppColors.muted),
          ),
          const SizedBox(height: AppSpacing.space4),
          Text(
            'WHAT HAPPENED?',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              letterSpacing: 0.6,
              fontWeight: FontWeight.w700,
              color: AppColors.red,
            ),
          ),
          const SizedBox(height: AppSpacing.space2),
          Wrap(
            spacing: AppSpacing.space2,
            runSpacing: AppSpacing.space2,
            children: ['Cardiac', 'Accident', 'Injury', 'Medical']
                .map(
                  (detail) => _PressScale(
                    child: _SelectionChip(
                      label: detail,
                      selected: state.selectedDetail == detail,
                      onPressed: () {
                        state.selectDetail(detail);
                      },
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: AppSpacing.space4),
          Text(
            'PEOPLE NEEDING HELP',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              letterSpacing: 0.6,
              fontWeight: FontWeight.w700,
              color: AppColors.red,
            ),
          ),
          const SizedBox(height: AppSpacing.space2),
          Wrap(
            spacing: AppSpacing.space2,
            runSpacing: AppSpacing.space2,
            children: [1, 2, 3, 4]
                .map(
                  (count) => _PressScale(
                    child: _SelectionChip(
                      label: count == 4 ? '4+' : '$count',
                      selected: state.peopleNeedingHelp == count,
                      onPressed: () {
                        state.selectPeopleNeedingHelp(count);
                      },
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: AppSpacing.space4),
          TextField(
            controller: _detailsController,
            minLines: 3,
            maxLines: 4,
            decoration: _emergencyField(
              label: 'Additional details',
              hint: 'Extra information, if you have time',
            ),
            onChanged: state.setAdditionalDetails,
          ),
          const SizedBox(height: AppSpacing.space5),
          _PressScale(
            child: _ActionButton(
              label: 'CONTINUE NOW',
              emergency: true,
              onPressed: ready
                  ? () {
                      state.setAdditionalDetails(_detailsController.text);
                      state.goTo(EmergencyScreen.emergencyConfirm);
                    }
                  : null,
            ),
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
            style: _largeTitle(context),
          ),
          const SizedBox(height: AppSpacing.space4),
          _InfoCard(
            title: state.resolvedAddress ?? 'Location',
            subtitle: 'Pinned on the map.',
            icon: Icons.location_on_rounded,
            highlighted: true,
          ),
          const SizedBox(height: AppSpacing.space3),
          _InfoCard(
            title:
                '${state.selectedDetail} · ${state.peopleNeedingHelp == 4 ? '4+' : state.peopleNeedingHelp} person${state.peopleNeedingHelp == 1 ? '' : 's'}',
            subtitle: state.additionalDetails == null ||
                    state.additionalDetails!.isEmpty
                ? 'Included with this request.'
                : state.additionalDetails!,
            icon: Icons.medical_information_rounded,
          ),
          const SizedBox(height: AppSpacing.space3),
          _InfoCard(
            title: 'Simulated arrival',
            subtitle: 'The backend receives a real request.',
            icon: Icons.timer_outlined,
          ),
          if(state.errorMessage != null) ...[
            const SizedBox(height: AppSpacing.space4),
            _ErrorNotice(message: state.errorMessage!),
          ],
          const SizedBox(height: AppSpacing.space6),
          _PressScale(
            child: _ActionButton(
              label: 'REQUEST NOW',
              emergency: true,
              onPressed: state.requestAmbulance,
            ),
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
            subtitle: assignment.distanceKm == null
                ? 'Assigned and on the way'
                : '${assignment.distanceKm!.toStringAsFixed(2)} km away',
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
          if(state.callerMessage != null) ...[
            const SizedBox(height: AppSpacing.space3),
            _InfoCard(
              title: 'Ambulance update',
              subtitle: state.callerMessage!,
              icon: Icons.swap_horiz_rounded,
              highlighted: true,
            ),
          ],
          const SizedBox(height: AppSpacing.space4),
          const _TripMap(),
          const SizedBox(height: AppSpacing.space3),
          Text(
            'Arrival simulation starts now: ${state.remainingSeconds} seconds remaining.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: AppColors.muted),
          ),
          if(state.hospitalError != null) ...[
            const SizedBox(height: AppSpacing.space4),
            _ErrorNotice(message: state.hospitalError!),
          ],
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
          if(state.callerMessage != null) ...[
            const SizedBox(height: AppSpacing.space3),
            _InfoCard(
              title: 'Ambulance update',
              subtitle: state.callerMessage!,
              icon: Icons.swap_horiz_rounded,
              highlighted: true,
            ),
          ],
          const SizedBox(height: AppSpacing.space4),
          const _TripMap(),
          const SizedBox(height: AppSpacing.space4),
          Text(
            '${state.remainingSeconds} seconds until arrival',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineMedium
                ?.copyWith(color: AppColors.red),
          ),
          if(state.hospitalError != null) ...[
            const SizedBox(height: AppSpacing.space4),
            _ErrorNotice(message: state.hospitalError!),
          ],
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
          if(state.callerMessage != null) ...[
            const SizedBox(height: AppSpacing.space3),
            _InfoCard(
              title: 'Ambulance update',
              subtitle: state.callerMessage!,
              icon: Icons.swap_horiz_rounded,
              highlighted: true,
            ),
          ],
          const SizedBox(height: AppSpacing.space4),
          const _TripMap(),
          if(state.remainingSeconds <= 0) ...[
            const SizedBox(height: AppSpacing.space4),
            Text(
              'Your ambulance is here',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: AppSpacing.space3),
            _AboutDriverRow(assignment: state.result?.assignedAmbulance),
          ],
          if(state.hospitalError != null) ...[
            const SizedBox(height: AppSpacing.space4),
            _ErrorNotice(message: state.hospitalError!),
          ],
          const SizedBox(height: AppSpacing.space4),
          const _DemoNotice(),
        ],
      ),
    );
  }
}

class _AboutDriverRow extends StatefulWidget {
  const _AboutDriverRow({required this.assignment});

  final AmbulanceAssignment? assignment;

  @override
  State<_AboutDriverRow> createState() => _AboutDriverRowState();
}

class _AboutDriverRowState extends State<_AboutDriverRow> {
  bool expanded = false;
  bool pressed = false;

  String shown(String? value) {
    final trimmed = value?.trim() ?? '';
    if(trimmed.isEmpty) {
      return 'N/A';
    }
    return trimmed;
  }

  @override
  Widget build(BuildContext context) {
    final assignment = widget.assignment;
    return GestureDetector(
      onTapDown: (_) {
        setState(() {
          pressed = true;
          expanded = !expanded;
        });
      },
      onTapUp: (_) {
        setState(() {
          pressed = false;
        });
      },
      onTapCancel: () {
        setState(() {
          pressed = false;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.all(AppSpacing.space3),
        decoration: BoxDecoration(
          color: pressed ? AppColors.line : AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.line, width: 2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'About driver',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            if(expanded) ...[
              const SizedBox(height: AppSpacing.space2),
              Text(
                'Ambulance: ${shown(assignment?.label)}',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              Text(
                'Driver: ${shown(assignment?.driverName)}',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              Text(
                'Phone: ${shown(assignment?.driverPhone)}',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ],
          ],
        ),
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
            const _TripMap(),
            if(state.callerMessage != null) ...[
              const SizedBox(height: AppSpacing.space3),
              _InfoCard(
              title: 'Ambulance update',
              subtitle: state.callerMessage!,
              icon: Icons.swap_horiz_rounded,
              highlighted: true,
            ),
            ],
            const SizedBox(height: AppSpacing.space3),
            Text(
              state.hospitalName ?? '',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            Text(
              state.hospitalAddress ?? '',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: AppSpacing.space3),
            Text(
              'Ambulance has arrived',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineLarge,
            ),
            const SizedBox(height: AppSpacing.space2),
            Text(
              assignment.label,
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
              context.read<EmergencyRequestState>().openDriverPortal();
            },
          ),
          const SizedBox(height: AppSpacing.space2),
          _ProfileRow(
            label: 'Switch to provider mode',
            onPressed: () {
              context.read<EmergencyRequestState>().startProviderMode(
                fromProfile: true,
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ProfileRow extends StatelessWidget {
  const _ProfileRow({required this.label, this.onPressed, this.trailing = '›'});

  final String label;
  final VoidCallback? onPressed;
  final String trailing;

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
                trailing,
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

String _scheduleLabel(BuildContext context, DateTime? scheduledAt) {
  if(scheduledAt == null) {
    return 'As soon as possible';
  }

  final localizations = MaterialLocalizations.of(context);
  final time = localizations.formatTimeOfDay(
    TimeOfDay.fromDateTime(scheduledAt),
  );
  return '${localizations.formatMediumDate(scheduledAt)} · $time';
}

class _ServicesScreen extends StatelessWidget {
  const _ServicesScreen();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<EmergencyRequestState>();

    return _FlowFrame(
      plainChrome: true,
      title: 'Services',
      tab: _UserTab.services,
      child: _SoftArrive(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('What do you need fixed?', style: _largeTitle(context)),
            const SizedBox(height: AppSpacing.space2),
            Text(
              'Take your time. Compare the right person for the job.',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: AppColors.muted,
                height: 1.45,
              ),
            ),
            const SizedBox(height: AppSpacing.space4),
            _PressScale(
              child: _ChoiceCard(
                quiet: true,
                emphasis: true,
                icon: Icons.plumbing,
                title: 'Plumber',
                subtitle: 'View options',
                color: AppColors.green,
                onTap: () {
                  state.openTrade('Plumber');
                },
              ),
            ),
            const SizedBox(height: AppSpacing.space3),
            _PressScale(
              child: _ChoiceCard(
                quiet: true,
                emphasis: true,
                icon: Icons.electrical_services,
                title: 'Electrician',
                subtitle: 'View options',
                color: AppColors.green,
                onTap: () {
                  state.openTrade('Electrician');
                },
              ),
            ),
            const SizedBox(height: AppSpacing.space3),
            _PressScale(
              child: _ChoiceCard(
                quiet: true,
                emphasis: true,
                icon: Icons.carpenter,
                title: 'Carpenter',
                subtitle: 'View options',
                color: AppColors.green,
                onTap: () {
                  state.openTrade('Carpenter');
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TradeDetailScreen extends StatelessWidget {
  const _TradeDetailScreen();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<EmergencyRequestState>();
    final plumber = state.domesticTrade == 'Plumber';
    final issues = plumber
        ? ['Pipe leak', 'Tap install', 'Water motor', 'Other']
        : ['Other'];

    return _FlowFrame(
      title: state.domesticTrade,
      tab: _UserTab.services,
      onBack: () {
        state.goTo(EmergencyScreen.services);
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            state.domesticTrade,
            style: Theme.of(context).textTheme.headlineLarge,
          ),
          const SizedBox(height: AppSpacing.space2),
          Text(
            plumber
                ? 'Leaks, pipes, taps, and water motors.'
                : 'Describe the job on the next screen.',
            style: Theme.of(context).textTheme.bodyLarge
                ?.copyWith(color: AppColors.muted),
          ),
          const SizedBox(height: AppSpacing.space4),
          Text('CHOOSE AN ISSUE', style: Theme.of(context).textTheme.labelSmall),
          const SizedBox(height: AppSpacing.space2),
          Wrap(
            spacing: AppSpacing.space2,
            runSpacing: AppSpacing.space2,
            children: issues
                .map(
                  (issue) => _SelectionChip(
                    label: issue,
                    selected: state.domesticIssue == issue,
                    onPressed: () {
                      state.selectDomesticIssue(issue);
                    },
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: AppSpacing.space4),
          Text('CHOOSE A PROVIDER', style: Theme.of(context).textTheme.labelSmall),
          const SizedBox(height: AppSpacing.space2),
          if(state.providersLoading)
            const Center(child: CircularProgressIndicator()),
          if(state.providersError != null) ...[
            _ErrorNotice(message: state.providersError!),
            const SizedBox(height: AppSpacing.space3),
            _SecondaryButton(label: 'Try again', onPressed: state.loadProviders),
          ],
          if(!state.providersLoading &&
              state.providersError == null &&
              state.providersForTrade.isEmpty)
            Text(
              'No ${state.domesticTrade.toLowerCase()} is listed right now.',
              style: Theme.of(context).textTheme.bodyLarge
                  ?.copyWith(color: AppColors.muted),
            ),
          for(final provider in state.providersForTrade) ...[
            _ChoiceCard(
              icon: Icons.person_rounded,
              title: provider.name,
              subtitle:
                  '${provider.specialisationName ?? state.domesticTrade} · ★ ${provider.rating.toStringAsFixed(1)} · Inspection fee Rs. ${provider.inspectionFee.toStringAsFixed(0)}',
              color: state.chosenProvider?.id == provider.id
                  ? AppColors.green
                  : AppColors.muted,
              onTap: () {
                state.chooseProvider(provider);
              },
            ),
            const SizedBox(height: AppSpacing.space2),
          ],
          const SizedBox(height: AppSpacing.space5),
          _ActionButton(
            label: 'Book ${state.domesticTrade.toLowerCase()}',
            color: AppColors.green,
            onPressed: state.chosenProvider == null
                ? null
                : () {
                    state.goTo(EmergencyScreen.serviceDescription);
                  },
          ),
        ],
      ),
    );
  }
}

class _ServiceDescriptionScreen extends StatelessWidget {
  const _ServiceDescriptionScreen();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<EmergencyRequestState>();
    final plumber = state.domesticTrade == 'Plumber';

    return _FlowFrame(
      title: 'Service details',
      tab: _UserTab.services,
      onBack: () {
        state.goTo(EmergencyScreen.tradeDetail);
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Describe the problem',
            style: Theme.of(context).textTheme.headlineLarge,
          ),
          const SizedBox(height: AppSpacing.space4),
          if(plumber) ...[
            Text(
              'SELECT SPECIFIC ISSUE',
              style: Theme.of(context).textTheme.labelSmall,
            ),
            const SizedBox(height: AppSpacing.space2),
            Wrap(
              spacing: AppSpacing.space2,
              runSpacing: AppSpacing.space2,
              children: ['Water leak', 'Low pressure', 'Blocked pipe']
                  .map(
                    (issue) => _SelectionChip(
                      label: issue,
                      selected: state.domesticSpecificIssue == issue,
                      onPressed: () {
                        state.selectSpecificIssue(issue);
                      },
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: AppSpacing.space4),
          ],
          TextFormField(
            initialValue: state.domesticDescription,
            minLines: 3,
            maxLines: 4,
            onChanged: state.setDomesticDescription,
            decoration: InputDecoration(
              labelText: 'Describe your service problem',
              hintText: plumber ? 'Kitchen sink leaking from pipe joint.' : null,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: AppSpacing.space3),
          _SecondaryButton(
            label: 'Add photo',
            onPressed: state.attachDomesticPhoto,
          ),
          if(state.domesticPhotoAttached) ...[
            const SizedBox(height: AppSpacing.space2),
            Text('Photo attached.', style: Theme.of(context).textTheme.bodyLarge),
          ],
          const SizedBox(height: AppSpacing.space5),
          _ActionButton(
            label: 'Continue',
            onPressed: () {
              state.goTo(EmergencyScreen.serviceLocation);
            },
          ),
        ],
      ),
    );
  }
}

class _ServiceLocationScreen extends StatefulWidget {
  const _ServiceLocationScreen();

  @override
  State<_ServiceLocationScreen> createState() => _ServiceLocationScreenState();
}

class _ServiceLocationScreenState extends State<_ServiceLocationScreen> {
  static const _openCenter = LatLng(24.8600, 67.0100);
  final _mapController = MapController();
  final _addressController = TextEditingController();
  var _busy = false;
  String? _message;

  @override
  void dispose() {
    _mapController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _useDeviceLocation() async {
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if(!serviceEnabled) {
        setState(() {
          _message = 'Location is turned off. Type the address instead.';
        });
        return;
      }

      var permission = await Geolocator.checkPermission();
      if(permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if(permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        setState(() {
          _message = 'Location permission is off. Type the address instead.';
        });
        return;
      }

      final position = await Geolocator.getCurrentPosition();
      if(!mounted) {
        return;
      }
      final state = context.read<EmergencyRequestState>();
      final address = await state.labelForCoordinates(
        position.latitude,
        position.longitude,
      );
      if(!mounted) {
        return;
      }
      _dropPin(
        state,
        latitude: position.latitude,
        longitude: position.longitude,
        address: address,
      );
    } catch (_) {
      if(!mounted) {
        return;
      }
      setState(() {
        _message = 'Your location could not be read. Type the address instead.';
      });
    } finally {
      if(mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  Future<void> _lookupAddress() async {
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final state = context.read<EmergencyRequestState>();
      final place = await state.lookupAddress(_addressController.text);
      if(!mounted) {
        return;
      }
      if(place == null) {
        setState(() {
          _message = 'That address was not found.';
        });
        return;
      }
      _dropPin(
        state,
        latitude: place.latitude,
        longitude: place.longitude,
        address: place.address,
      );
    } catch (_) {
      if(!mounted) {
        return;
      }
      setState(() {
        _message = 'The address lookup did not finish. Try again.';
      });
    } finally {
      if(mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  void _dropPin(
    EmergencyRequestState state, {
    required double latitude,
    required double longitude,
    required String address,
  }) {
    state.setDomesticPin(
      latitude: latitude,
      longitude: longitude,
      address: address,
    );
    _mapController.move(LatLng(latitude, longitude), 16);
    setState(() {
      _message = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<EmergencyRequestState>();
    final pin = state.domesticPinLatitude == null ||
            state.domesticPinLongitude == null
        ? null
        : LatLng(state.domesticPinLatitude!, state.domesticPinLongitude!);

    return _FlowFrame(
      title: 'Location',
      tab: _UserTab.services,
      onBack: () {
        state.goTo(EmergencyScreen.serviceDescription);
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Where should we send the provider?',
            style: Theme.of(context).textTheme.headlineLarge,
          ),
          const SizedBox(height: AppSpacing.space4),
          SizedBox(
            height: 220,
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: pin ?? _openCenter,
                initialZoom: pin == null ? 12 : 16,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.madadplus.madad_plus_mobile',
                  tileProvider: Platform.environment['FLUTTER_TEST'] == 'true'
                      ? _TestTileProvider()
                      : NetworkTileProvider(),
                ),
                if(pin != null)
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: pin,
                        width: 40,
                        height: 40,
                        child: const Icon(
                          Icons.location_on,
                          color: AppColors.red,
                          size: 40,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.space4),
          _ActionButton(
            label: 'Find my location',
            onPressed: _busy ? null : _useDeviceLocation,
          ),
          const SizedBox(height: AppSpacing.space4),
          TextField(
            controller: _addressController,
            decoration: const InputDecoration(
              labelText: 'Address',
              border: OutlineInputBorder(),
            ),
            textInputAction: TextInputAction.search,
            onSubmitted: (_) {
              if(!_busy) {
                _lookupAddress();
              }
            },
          ),
          const SizedBox(height: AppSpacing.space3),
          _ActionButton(
            label: 'Show on map',
            onPressed: _busy ? null : _lookupAddress,
          ),
          if(_message != null) ...[
            const SizedBox(height: AppSpacing.space4),
            _ErrorNotice(message: _message!),
          ],
          const SizedBox(height: AppSpacing.space5),
          _ActionButton(
            label: 'Continue',
            onPressed: pin == null
                ? null
                : () {
                    state.goTo(EmergencyScreen.serviceSchedule);
                  },
          ),
        ],
      ),
    );
  }
}

class _ServiceScheduleScreen extends StatelessWidget {
  const _ServiceScheduleScreen();

  Future<void> pickLater(
    BuildContext context,
    EmergencyRequestState state,
  ) async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 30)),
    );
    if(date == null || !context.mounted) {
      return;
    }

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(now),
    );
    if(time == null) {
      return;
    }

    state.scheduleDomestic(
      DateTime(date.year, date.month, date.day, time.hour, time.minute),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<EmergencyRequestState>();
    final later = state.domesticScheduledAt != null;

    return _FlowFrame(
      title: 'Schedule',
      tab: _UserTab.services,
      onBack: () {
        state.goTo(EmergencyScreen.serviceLocation);
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'When do you need help?',
            style: Theme.of(context).textTheme.headlineLarge,
          ),
          const SizedBox(height: AppSpacing.space4),
          _ChoiceCard(
            icon: Icons.bolt,
            title: 'As soon as possible',
            subtitle: 'Within about one hour',
            color: later ? AppColors.muted : AppColors.green,
            onTap: () {
              state.scheduleDomestic(null);
            },
          ),
          const SizedBox(height: AppSpacing.space3),
          _ChoiceCard(
            icon: Icons.schedule,
            title: 'Schedule for later',
            subtitle: later
                ? _scheduleLabel(context, state.domesticScheduledAt)
                : 'Choose date and time',
            color: later ? AppColors.green : AppColors.muted,
            onTap: () {
              pickLater(context, state);
            },
          ),
          const SizedBox(height: AppSpacing.space5),
          _ActionButton(
            label: 'Continue',
            onPressed: () {
              state.goTo(EmergencyScreen.serviceConfirm);
            },
          ),
        ],
      ),
    );
  }
}

class _ServiceConfirmScreen extends StatelessWidget {
  const _ServiceConfirmScreen();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<EmergencyRequestState>();

    return _FlowFrame(
      title: 'Confirm service',
      tab: _UserTab.services,
      onBack: () {
        state.goTo(EmergencyScreen.serviceSchedule);
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Confirm your request',
            style: Theme.of(context).textTheme.headlineLarge,
          ),
          const SizedBox(height: AppSpacing.space4),
          _InfoCard(
            title: '${state.domesticTrade} · ${state.domesticIssue}',
            subtitle:
                '${state.domesticAddress.trim()} · ${_scheduleLabel(context, state.domesticScheduledAt)}',
            icon: Icons.handyman_rounded,
          ),
          if(state.chosenProvider != null) ...[
            const SizedBox(height: AppSpacing.space3),
            _InfoCard(
              title: state.chosenProvider!.name,
              subtitle: '★ ${state.chosenProvider!.rating.toStringAsFixed(1)}',
              icon: Icons.person_rounded,
            ),
          ],
          const SizedBox(height: AppSpacing.space4),
          Text(
            'Inspection fee: ${state.inspectionFeeText}. Repair cost is set after the visit.',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          if(state.domesticNotice != null) ...[
            const SizedBox(height: AppSpacing.space3),
            _ErrorNotice(message: state.domesticNotice!),
          ],
          const SizedBox(height: AppSpacing.space5),
          Row(
            children: [
              Expanded(
                child: _SecondaryButton(
                  label: 'Cancel',
                  onPressed: state.cancelDomestic,
                ),
              ),
              const SizedBox(width: AppSpacing.space3),
              Expanded(
                child: _ActionButton(
                  label: 'Confirm',
                  onPressed: state.domesticSending ? null : state.confirmDomestic,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DomesticJobScreen extends StatefulWidget {
  const _DomesticJobScreen();

  @override
  State<_DomesticJobScreen> createState() => _DomesticJobScreenState();
}

class _DomesticJobScreenState extends State<_DomesticJobScreen> {
  bool showingProfile = false;
  int stars = 0;

  String providerName(EmergencyRequestState state) {
    return state.domesticBooking?.providerName ??
        state.chosenProvider?.name ??
        state.providerProfile?.name ??
        'Your provider';
  }

  String providerTrade(EmergencyRequestState state) {
    return state.domesticBooking?.specialisationName ??
        state.chosenProvider?.specialisationName ??
        state.domesticTrade;
  }

  String providerRating(EmergencyRequestState state) {
    final rating =
        state.domesticBooking?.providerRating ?? state.chosenProvider?.rating;
    return rating == null ? 'No rating yet' : '★ ${rating.toStringAsFixed(1)}';
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<EmergencyRequestState>();

    if(showingProfile) {
      return providerProfile(context, state);
    }

    return switch(state.domesticJob) {
      DomesticJob.idle || DomesticJob.searching => searching(context, state),
      DomesticJob.assigned => assigned(context, state),
      DomesticJob.enRoute => enRoute(context, state),
      DomesticJob.inProgress ||
      DomesticJob.costReview => inProgress(context, state),
      DomesticJob.refused => refused(context, state),
      DomesticJob.complete => rating(context, state),
    };
  }

  Widget notice(BuildContext context, EmergencyRequestState state) {
    if(state.domesticNotice == null) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.space3),
      child: Text(
        state.domesticNotice!,
        style: Theme.of(context).textTheme.bodyLarge,
      ),
    );
  }

  Widget callAndChat(EmergencyRequestState state) {
    return Row(
      children: [
        Expanded(
          child: _SecondaryButton(
            label: 'Call',
            onPressed: () {
              state.showDomesticNotice('No call was placed.');
            },
          ),
        ),
        const SizedBox(width: AppSpacing.space3),
        Expanded(
          child: _SecondaryButton(
            label: 'Chat',
            onPressed: () {
              state.showDomesticNotice('No message was sent.');
            },
          ),
        ),
      ],
    );
  }

  Widget searching(BuildContext context, EmergencyRequestState state) {
    return _FlowFrame(
      title: 'Finding a provider',
      tab: _UserTab.services,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppSpacing.space6),
          const Center(
            child: SizedBox(
              width: 52,
              height: 52,
              child: CircularProgressIndicator(
                color: AppColors.green,
                strokeWidth: 6,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.space5),
          Text(
            'Finding a ${state.domesticTrade.toLowerCase()}',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineLarge,
          ),
          const SizedBox(height: AppSpacing.space3),
          Text(
            'Matching you with an available provider nearby.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge
                ?.copyWith(color: AppColors.muted),
          ),
          const SizedBox(height: AppSpacing.space2),
          Text(
            'The provider accepts this from the provider sign-in.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge
                ?.copyWith(color: AppColors.muted),
          ),
          const SizedBox(height: AppSpacing.space6),
          _SecondaryButton(
            label: 'Cancel request',
            onPressed: state.cancelDomestic,
          ),
        ],
      ),
    );
  }

  Widget assigned(BuildContext context, EmergencyRequestState state) {
    return _FlowFrame(
      title: 'Provider assigned',
      tab: _UserTab.services,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _StatusPill(label: 'Provider found', color: AppColors.green),
          const SizedBox(height: AppSpacing.space3),
          _InfoCard(
            title: providerName(state),
            subtitle: '${providerRating(state)} · ${providerTrade(state)}',
            icon: Icons.person_rounded,
          ),
          const SizedBox(height: AppSpacing.space3),
          Text(
            'Other providers no longer see this request.',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: AppSpacing.space2),
          Text(
            'Inspection fee: ${state.inspectionFeeText}',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          notice(context, state),
          const SizedBox(height: AppSpacing.space5),
          _ActionButton(
            label: 'Track on map',
            onPressed: state.trackProvider,
          ),
          const SizedBox(height: AppSpacing.space3),
          callAndChat(state),
          const SizedBox(height: AppSpacing.space3),
          _SecondaryButton(
            label: 'View profile',
            onPressed: () {
              setState(() {
                showingProfile = true;
              });
            },
          ),
          const SizedBox(height: AppSpacing.space3),
          _SecondaryButton(
            label: 'Cancel',
            onPressed: state.cancelAssignedProvider,
          ),
        ],
      ),
    );
  }

  Widget providerProfile(BuildContext context, EmergencyRequestState state) {
    return _FlowFrame(
      title: 'Provider profile',
      tab: _UserTab.services,
      onBack: () {
        setState(() {
          showingProfile = false;
        });
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Align(
            child: CircleAvatar(
              radius: 26,
              backgroundColor: AppColors.green,
              child: Icon(
                Icons.person,
                color: AppColors.surface,
                size: 24,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.space2),
          Text(
            providerName(state),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          Text(
            providerTrade(state),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge
                ?.copyWith(color: AppColors.muted),
          ),
          Text(
            providerRating(state),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ],
      ),
    );
  }

  Widget enRoute(BuildContext context, EmergencyRequestState state) {
    return _FlowFrame(
      title: 'Provider en route',
      tab: _UserTab.services,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _InfoCard(
            title: '${providerName(state)} · ${providerTrade(state)}',
            subtitle: state.domesticIssue,
            icon: Icons.person_rounded,
          ),
          const SizedBox(height: AppSpacing.space3),
          const _MapBlock(),
          notice(context, state),
          const SizedBox(height: AppSpacing.space3),
          callAndChat(state),
          const SizedBox(height: AppSpacing.space3),
          Text(
            'The provider marks arrival from the provider sign-in.',
            style: Theme.of(context).textTheme.bodyLarge
                ?.copyWith(color: AppColors.muted),
          ),
        ],
      ),
    );
  }

  Widget inProgress(BuildContext context, EmergencyRequestState state) {
    return _FlowFrame(
      title: 'Service in progress',
      tab: _UserTab.services,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppSpacing.space5),
          const Icon(
            Icons.handyman_rounded,
            color: AppColors.green,
            size: 52,
          ),
          const SizedBox(height: AppSpacing.space3),
          Text(
            '${providerName(state)} has started work',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineLarge,
          ),
          const SizedBox(height: AppSpacing.space2),
          Text(
            state.domesticIssue,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge
                ?.copyWith(color: AppColors.muted),
          ),
          const SizedBox(height: AppSpacing.space4),
          const _InfoCard(
            title: 'Need help?',
            subtitle: 'Contact support if something is wrong.',
            icon: Icons.support_agent_rounded,
          ),
          notice(context, state),
          const SizedBox(height: AppSpacing.space3),
          Text(
            'The provider completes the job from the provider sign-in.',
            style: Theme.of(context).textTheme.bodyLarge
                ?.copyWith(color: AppColors.muted),
          ),
          const SizedBox(height: AppSpacing.space5),
          _SecondaryButton(
            label: 'Contact support',
            onPressed: () {
              state.showDomesticNotice('Support was not contacted.');
            },
          ),
        ],
      ),
    );
  }

  Widget refused(BuildContext context, EmergencyRequestState state) {
    return _FlowFrame(
      title: 'Confirm final cost',
      tab: _UserTab.services,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Inspection fee only',
            style: Theme.of(context).textTheme.headlineLarge,
          ),
          const SizedBox(height: AppSpacing.space3),
          Text(
            state.amountOwed!,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: AppSpacing.space5),
          _ActionButton(
            label: 'Back to services',
            onPressed: () {
              state.finishDomestic(EmergencyScreen.services);
            },
          ),
        ],
      ),
    );
  }

  Widget rating(BuildContext context, EmergencyRequestState state) {
    return _FlowFrame(
      title: 'Service complete',
      tab: _UserTab.services,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppSpacing.space5),
          const Icon(
            Icons.check_circle_rounded,
            color: AppColors.green,
            size: 52,
          ),
          const SizedBox(height: AppSpacing.space3),
          Text(
            'How was ${providerName(state)}?',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineLarge,
          ),
          const SizedBox(height: AppSpacing.space2),
          Text(
            'Your rating helps other customers choose.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge
                ?.copyWith(color: AppColors.muted),
          ),
          const SizedBox(height: AppSpacing.space3),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for(var star = 1; star <= 5; star++)
                IconButton(
                  tooltip: 'Rate $star stars',
                  icon: Icon(
                    star <= stars ? Icons.star_rounded : Icons.star_border_rounded,
                    color: AppColors.orange,
                    size: 36,
                  ),
                  onPressed: () {
                    setState(() {
                      stars = star;
                    });
                  },
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.space3),
          const TextField(
            minLines: 3,
            maxLines: 4,
            decoration: InputDecoration(
              labelText: 'Optional service review',
              hintText: 'Add a review (optional)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: AppSpacing.space5),
          _ActionButton(
            label: 'Submit rating',
            onPressed: () {
              state.finishDomestic(EmergencyScreen.home);
            },
          ),
          const SizedBox(height: AppSpacing.space3),
          _SecondaryButton(
            label: 'Skip',
            onPressed: () {
              state.finishDomestic(EmergencyScreen.home);
            },
          ),
        ],
      ),
    );
  }
}

class _CostReviewScreen extends StatefulWidget {
  const _CostReviewScreen();

  @override
  State<_CostReviewScreen> createState() => _CostReviewScreenState();
}

class _CostReviewScreenState extends State<_CostReviewScreen> {
  final repairTotal = TextEditingController();

  @override
  void dispose() {
    repairTotal.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<EmergencyRequestState>();
    final typedTotal = repairTotal.text.trim();
    final provider = state.costFromProvider;
    final decided = provider && state.amountOwed != null;
    final showField = provider && !state.costWaiting && !decided;
    final booking = state.domesticBooking;
    final quoted = provider ? null : booking?.quotedTotal;
    final receiptFee = booking?.receiptInspectionFee;
    double? decidedFee;
    if(provider) {
      for(final job in state.providerJobs) {
        if(job.finalTotal != null && job.receiptInspectionFee != null) {
          decidedFee = job.receiptInspectionFee;
        }
      }
    }
    final feeNumber = receiptFee ?? decidedFee;
    final feeText = feeNumber != null
        ? 'Rs. ${feeNumber.toStringAsFixed(0)}'
        : state.inspectionFeeText;
    final shownTotal = provider
        ? (typedTotal.isEmpty ? null : typedTotal)
        : quoted?.toStringAsFixed(0);

    return _FlowFrame(
      title: 'Confirm final cost',
      tab: state.costFromProvider ? null : _UserTab.services,
      onBack: state.backFromCostReview,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Review before payment',
            style: Theme.of(context).textTheme.headlineLarge,
          ),
          const SizedBox(height: AppSpacing.space4),
          if(showField)
            TextField(
              controller: repairTotal,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged: (_) {
                setState(() {});
              },
              decoration: const InputDecoration(
                labelText: 'Repair total',
                helperText: 'This amount does not include the inspection fee.',
                border: OutlineInputBorder(),
              ),
            ),
          if(!showField && shownTotal != null)
            Text(
              'Repair total: $shownTotal',
              style: Theme.of(context).textTheme.labelLarge,
            ),
          const SizedBox(height: AppSpacing.space3),
          Text(
            'Inspection fee: $feeText',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          if(!provider && quoted != null && receiptFee != null) ...[
            const SizedBox(height: AppSpacing.space3),
            Text(
              'Total: Rs. ${(quoted + receiptFee).toStringAsFixed(0)}',
              style: Theme.of(context).textTheme.labelLarge,
            ),
          ],
          if(showField && typedTotal.isEmpty) ...[
            const SizedBox(height: AppSpacing.space2),
            Text(
              'Waiting for the repair total.',
              style: Theme.of(context).textTheme.bodyLarge
                  ?.copyWith(color: AppColors.muted),
            ),
          ],
          if(decided) ...[
            const SizedBox(height: AppSpacing.space3),
            Text(
              state.amountOwed!,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
          ],
          if(state.domesticNotice != null) ...[
            const SizedBox(height: AppSpacing.space3),
            Text(
              state.domesticNotice!,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ],
          const SizedBox(height: AppSpacing.space5),
          if(provider && state.costWaiting)
            const Center(child: CircularProgressIndicator()),
          if(showField && typedTotal.isNotEmpty) ...[
            _ActionButton(
              label: 'Submit',
              color: AppColors.green,
              onPressed: () {
                state.submitRepairTotal(typedTotal);
              },
            ),
            const SizedBox(height: AppSpacing.space3),
          ],
          if(!provider) ...[
            _ActionButton(
              label: 'Accept',
              color: AppColors.green,
              onPressed: () {
                state.decideRepairTotal(accept: true);
              },
            ),
            const SizedBox(height: AppSpacing.space3),
            _SecondaryButton(
              label: 'Refuse',
              onPressed: () {
                state.decideRepairTotal(accept: false);
              },
            ),
          ],
          if(showField)
            _SecondaryButton(
              label: 'Report an issue',
              onPressed: () {
                state.showDomesticNotice('The issue was saved on this phone.');
              },
            ),
        ],
      ),
    );
  }
}

class _RequestsScreen extends StatefulWidget {
  const _RequestsScreen();

  @override
  State<_RequestsScreen> createState() => _RequestsScreenState();
}

class _RequestsScreenState extends State<_RequestsScreen> {
  int? openedEntry;

  @override
  Widget build(BuildContext context) {
    final history = context.watch<EmergencyRequestState>().domesticHistory;

    return _FlowFrame(
      title: 'Requests',
      tab: _UserTab.requests,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if(history.isNotEmpty) ...[
            Text('HISTORY', style: Theme.of(context).textTheme.labelSmall),
            const SizedBox(height: AppSpacing.space2),
          ],
          for(var index = 0; index < history.length; index++) ...[
            _ProfileRow(
              label: history[index].label,
              onPressed: () {
                setState(() {
                  openedEntry = index;
                });
              },
            ),
            const SizedBox(height: AppSpacing.space2),
          ],
          if(openedEntry != null) ...[
            const SizedBox(height: AppSpacing.space2),
            Text(
              history[openedEntry!].owed,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ],
        ],
      ),
    );
  }
}

class _ProviderDashboardScreen extends StatefulWidget {
  const _ProviderDashboardScreen();

  @override
  State<_ProviderDashboardScreen> createState() =>
      _ProviderDashboardScreenState();
}

class _ProviderDashboardScreenState extends State<_ProviderDashboardScreen> {
  String? typedFee;

  List<Widget> providerLoadNotes(
    BuildContext context,
    EmergencyRequestState state,
  ) {
    return [
      if(state.providersLoading)
        const Center(child: CircularProgressIndicator()),
      if(state.providersError != null) ...[
        _ErrorNotice(message: state.providersError!),
        const SizedBox(height: AppSpacing.space3),
        _SecondaryButton(label: 'Try again', onPressed: state.loadProviders),
        const SizedBox(height: AppSpacing.space3),
      ],
    ];
  }

  Widget pickProfile(BuildContext context, EmergencyRequestState state) {
    if(state.providerDemo) {
      return demoProviderList(context, state);
    }
    if(state.providerTrade == null) {
      return tradeQuestion(context, state);
    }
    return confirmBusiness(context, state);
  }

  Widget tradeQuestion(BuildContext context, EmergencyRequestState state) {
    return _FlowFrame(
      title: 'Your trade',
      onBack: state.leaveProviderMode,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'What work do you do?',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: AppSpacing.space4),
          ...providerLoadNotes(context, state),
          for(final trade in state.providerTradeNames) ...[
            _ProfileRow(
              label: trade,
              onPressed: () {
                state.chooseProviderTrade(trade);
              },
            ),
            const SizedBox(height: AppSpacing.space2),
          ],
        ],
      ),
    );
  }

  Widget confirmBusiness(BuildContext context, EmergencyRequestState state) {
    final trade = state.providerTrade ?? '';
    final matches = state.providersForSignInTrade(trade);
    final waiting = state.providersLoading && state.providers.isEmpty;

    return _FlowFrame(
      title: 'Your business',
      onBack: state.leaveProviderMode,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Is this you?',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: AppSpacing.space4),
          ...providerLoadNotes(context, state),
          if(!waiting && matches.length == 1) ...[
            _ProfileRow(
              label:
                  '${matches.first.name} · ${matches.first.specialisationName ?? 'Provider'}',
              trailing: '',
            ),
            const SizedBox(height: AppSpacing.space3),
            _ActionButton(
              label: 'Yes, continue',
              onPressed: () {
                state.chooseProviderProfile(matches.first);
              },
            ),
          ],
          if(!waiting && matches.isEmpty && state.providersError == null)
            Text(
              'No $trade is signed up yet.',
              style: Theme.of(context).textTheme.bodyLarge
                  ?.copyWith(color: AppColors.muted),
            ),
          if(!waiting && matches.length > 1)
            Text(
              'More than one business does this work, so this screen cannot pick one.',
              style: Theme.of(context).textTheme.bodyLarge
                  ?.copyWith(color: AppColors.muted),
            ),
          const SizedBox(height: AppSpacing.space3),
          _SecondaryButton(
            label: 'Choose a different trade',
            onPressed: state.clearProviderTrade,
          ),
        ],
      ),
    );
  }

  Widget demoProviderList(BuildContext context, EmergencyRequestState state) {
    return _FlowFrame(
      title: 'Demo: act as a provider',
      onBack: state.leaveProviderMode,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Which provider do you want to test as?',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: AppSpacing.space2),
          Text(
            'Demo only. Anyone can open any provider here.',
            style: Theme.of(context).textTheme.bodyLarge
                ?.copyWith(color: AppColors.muted),
          ),
          const SizedBox(height: AppSpacing.space4),
          ...providerLoadNotes(context, state),
          for(final provider in state.providers) ...[
            _ProfileRow(
              label:
                  '${provider.name} · ${provider.specialisationName ?? 'Provider'}',
              onPressed: () {
                state.chooseProviderProfile(provider);
              },
            ),
            const SizedBox(height: AppSpacing.space2),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<EmergencyRequestState>();
    final provider = state.providerProfile;
    if(provider == null) {
      return pickProfile(context, state);
    }

    final offline = state.providerDuty == ProviderDuty.offline;
    final onJob = state.providerDuty == ProviderDuty.onJob;
    final (dutyLabel, dutyColor) = switch(state.providerDuty) {
      ProviderDuty.available => ('Available', AppColors.green),
      ProviderDuty.offline => ('Offline', AppColors.muted),
      ProviderDuty.onJob => ('On a job', AppColors.blue),
    };
    final savedFee = provider.inspectionFee.toStringAsFixed(0);
    final incoming = state.incomingJobs;
    final accepted = state.acceptedJobs;
    final finished = [
      for(final job in accepted)
        if(job.requestId != state.activeJobId && job.receiptStatus == 'ACCEPTED')
          job,
    ];

    final plateColor = switch(state.providerDuty) {
      ProviderDuty.available => AppColors.green,
      ProviderDuty.offline => AppColors.muted,
      ProviderDuty.onJob => AppColors.blue,
    };
    final upcoming = [
      for(final job in accepted)
        if(job.requestId == state.activeJobId || job.receiptStatus != 'ACCEPTED')
          job,
    ];

    return _FlowFrame(
      title: 'Provider dashboard',
      plainChrome: true,
      onBack: state.leaveProviderMode,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 64,
                height: 64,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: plateColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(Icons.person_outline, color: plateColor, size: 30),
              ),
              const SizedBox(width: AppSpacing.space4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(provider.name, style: _sectionTitle(context)),
                    const SizedBox(height: AppSpacing.space1),
                    Text(
                      '${provider.specialisationName ?? 'Provider'} · ${provider.rating.toStringAsFixed(1)} rating',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: AppColors.muted,
                        height: 1.35,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ),
            ],
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
                color: dutyColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(99),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: dutyColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.space2),
                  Text(
                    dutyLabel,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: dutyColor,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if(!onJob) ...[
            const SizedBox(height: AppSpacing.space4),
            if(offline)
              _PressScale(
                child: _ActionButton(
                  label: 'Tap to go online',
                  onPressed: () {
                    state.setProviderOnline(true);
                  },
                ),
              )
            else
              _InsetGroup(
                children: [
                  _InsetRow(
                    label: 'Tap to go offline',
                    showChevron: false,
                    onPressed: () {
                      state.setProviderOnline(false);
                    },
                  ),
                ],
              ),
          ],
          if(state.amountOwed != null) ...[
            const SizedBox(height: AppSpacing.space3),
            Text(
              state.amountOwed!,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.space5),
          _providerSectionLabel(context, 'INSPECTION FEE'),
          const SizedBox(height: AppSpacing.space2),
          _InsetGroup(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.space4,
                  AppSpacing.space2,
                  AppSpacing.space4,
                  AppSpacing.space2,
                ),
                child: TextFormField(
                  key: ValueKey('fee-${provider.id}'),
                  initialValue: savedFee,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                  onChanged: (value) {
                    typedFee = value;
                  },
                  decoration: const InputDecoration(
                    labelText: 'Inspection fee (Rs.)',
                    helperText: 'Customers see this next to your rating.',
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: AppColors.focus, width: 1.5),
                    ),
                    filled: false,
                    isDense: true,
                  ),
                ),
              ),
              _InsetRow(
                label: 'Save fee',
                showChevron: false,
                onPressed: () {
                  state.saveInspectionFee(typedFee ?? savedFee);
                },
              ),
            ],
          ),
          if(state.domesticNotice != null) ...[
            const SizedBox(height: AppSpacing.space3),
            Text(
              state.domesticNotice!,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ],
          const SizedBox(height: AppSpacing.space5),
          _providerSectionLabel(context, 'INCOMING REQUEST'),
          const SizedBox(height: AppSpacing.space2),
          if(offline)
            Text(
              'You are offline.',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: AppColors.muted,
                height: 1.4,
              ),
            )
          else if(state.providerJobsLoading && state.providerJobs.isEmpty)
            const Center(child: CircularProgressIndicator())
          else if(incoming.isEmpty)
            Text(
              'No new requests.',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: AppColors.muted,
                height: 1.4,
              ),
            )
          else
            for(final job in incoming) ...[
              _PressScale(
                child: _ChoiceCard(
                  quiet: true,
                  icon: Icons.handyman_outlined,
                  title: job.description,
                  subtitle:
                      '${job.address} · ${job.userName ?? 'Customer'} · Inspection fee Rs. ${(job.inspectionFee ?? provider.inspectionFee).toStringAsFixed(0)}',
                  color: AppColors.green,
                  onTap: () {
                    state.openJob(job.requestId);
                  },
                ),
              ),
              const SizedBox(height: AppSpacing.space3),
            ],
          const SizedBox(height: AppSpacing.space5),
          _providerSectionLabel(context, "TODAY'S JOBS"),
          const SizedBox(height: AppSpacing.space2),
          if(upcoming.isNotEmpty)
            _InsetGroup(
              children: [
                for(final job in upcoming)
                  _InsetRow(
                    label:
                        '${job.requestId == state.activeJobId ? 'Active job' : 'Accepted'} · ${job.description}',
                    onPressed: () {
                      state.openActiveJob(job.requestId);
                    },
                  ),
              ],
            )
          else
            Text(
              'No upcoming jobs.',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: AppColors.muted,
                height: 1.4,
              ),
            ),
          if(finished.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.space5),
            _providerSectionLabel(context, 'FINISHED'),
            const SizedBox(height: AppSpacing.space2),
            _InsetGroup(
              children: [
                for(final job in finished)
                  _InsetRow(
                    label: 'Finished · ${job.description}',
                    onPressed: () {
                      state.openFinishedJob(job.requestId);
                    },
                  ),
              ],
            ),
          ],
          const SizedBox(height: AppSpacing.space5),
          _GroupedLinks(
            links: [
              _GroupedLink('Refresh jobs', state.loadProviderJobs),
              _GroupedLink('Change provider', state.changeProviderProfile),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProviderRequestScreen extends StatelessWidget {
  const _ProviderRequestScreen();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<EmergencyRequestState>();
    final job = state.openedJob;
    final onJob = state.providerDuty == ProviderDuty.onJob;
    final pending = job?.status == 'PENDING';
    final canAccept = pending && !onJob;
    final String? reason;
    if(job == null) {
      reason = 'This request is no longer on this phone.';
    }
    else if(!pending) {
      reason = 'This request was already accepted.';
    }
    else if(onJob) {
      reason = 'Finish the active job before taking this one.';
    }
    else {
      reason = null;
    }

    return _FlowFrame(
      title: 'Request details',
      onBack: () {
        state.goTo(EmergencyScreen.providerDashboard);
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if(job != null) ...[
            _InfoCard(
              title: job.specialisationName ?? 'Job request',
              subtitle: 'Customer: ${job.userName ?? 'name not sent'}',
              icon: Icons.handyman_rounded,
            ),
            const SizedBox(height: AppSpacing.space3),
            _InfoCard(
              title: 'Problem',
              subtitle: job.description,
              icon: Icons.description_outlined,
            ),
            const SizedBox(height: AppSpacing.space3),
            _InfoCard(
              title: 'Location',
              subtitle: job.address,
              icon: Icons.location_on_rounded,
            ),
            const SizedBox(height: AppSpacing.space3),
            Text(
              'Inspection fee: ${job.inspectionFee == null ? 'not sent' : 'Rs. ${job.inspectionFee!.toStringAsFixed(0)}'}',
              style: Theme.of(context).textTheme.labelLarge,
            ),
          ],
          if(state.domesticNotice != null) ...[
            const SizedBox(height: AppSpacing.space4),
            _ErrorNotice(message: state.domesticNotice!),
          ],
          if(reason != null) ...[
            const SizedBox(height: AppSpacing.space4),
            Text(reason, style: Theme.of(context).textTheme.bodyLarge),
          ],
          const SizedBox(height: AppSpacing.space5),
          if(canAccept) ...[
            _ActionButton(
              label: 'Accept job',
              color: AppColors.green,
              onPressed: state.acceptJob,
            ),
            const SizedBox(height: AppSpacing.space3),
          ],
          if(pending)
            _SecondaryButton(
              label: 'Decline',
              onPressed: state.declineJob,
            ),
        ],
      ),
    );
  }
}

class _ProviderAcceptedScreen extends StatelessWidget {
  const _ProviderAcceptedScreen();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<EmergencyRequestState>();

    return _FlowFrame(
      title: 'Job accepted',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppSpacing.space5),
          const Icon(
            Icons.check_circle_rounded,
            color: AppColors.green,
            size: 52,
          ),
          const SizedBox(height: AppSpacing.space3),
          Text(
            'Customer notified',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineLarge,
          ),
          const SizedBox(height: AppSpacing.space2),
          Text(
            "Start navigating when you're ready.",
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge
                ?.copyWith(color: AppColors.muted),
          ),
          const SizedBox(height: AppSpacing.space3),
          Text(
            'Other providers no longer see this request.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          if(state.domesticNotice != null) ...[
            const SizedBox(height: AppSpacing.space3),
            Text(
              state.domesticNotice!,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ],
          const SizedBox(height: AppSpacing.space5),
          _ActionButton(
            label: 'Navigate to customer',
            onPressed: () {
              state.goTo(EmergencyScreen.providerJob);
            },
          ),
          const SizedBox(height: AppSpacing.space3),
          _SecondaryButton(
            label: 'Call customer',
            onPressed: () {
              state.showDomesticNotice('No call was placed.');
            },
          ),
        ],
      ),
    );
  }
}

class _ProviderJobScreen extends StatefulWidget {
  const _ProviderJobScreen();

  @override
  State<_ProviderJobScreen> createState() => _ProviderJobScreenState();
}

class _ProviderJobScreenState extends State<_ProviderJobScreen> {
  bool showingMap = false;
  bool photoAttached = false;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<EmergencyRequestState>();
    final finishedJob = state.finishedJob;
    if(state.finishedJobId != null) {
      return _FlowFrame(
        title: 'Finished job',
        onBack: state.closeFinishedJob,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _InfoCard(
              title: finishedJob?.specialisationName ?? 'Job',
              subtitle: finishedJob == null
                  ? 'This job is no longer on this phone.'
                  : '${finishedJob.userName ?? 'Customer'} · ${finishedJob.address}',
              icon: Icons.handyman_rounded,
            ),
            if(finishedJob != null) ...[
              const SizedBox(height: AppSpacing.space3),
              _InfoCard(
                title: 'Problem',
                subtitle: finishedJob.description,
                icon: Icons.description_outlined,
              ),
              if(finishedJob.finalTotal != null) ...[
                const SizedBox(height: AppSpacing.space3),
                Text(
                  'Price: Rs. ${finishedJob.finalTotal!.toStringAsFixed(0)}',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ],
            ],
          ],
        ),
      );
    }
    final job = state.activeJob;
    final started = state.domesticJob == DomesticJob.inProgress;

    return _FlowFrame(
      title: 'Active job',
      onBack: () {
        state.goTo(EmergencyScreen.providerDashboard);
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _InfoCard(
            title: job?.specialisationName ?? 'Job',
            subtitle: job == null
                ? 'This job is no longer on this phone.'
                : '${job.userName ?? 'Customer'} · ${job.address}',
            icon: Icons.handyman_rounded,
          ),
          if(job != null) ...[
            const SizedBox(height: AppSpacing.space3),
            _InfoCard(
              title: 'Problem',
              subtitle: job.description,
              icon: Icons.description_outlined,
            ),
          ],
          const SizedBox(height: AppSpacing.space3),
          _ActionButton(
            label: 'Navigate to customer',
            onPressed: () {
              setState(() {
                showingMap = true;
              });
            },
          ),
          if(showingMap) ...[
            const SizedBox(height: AppSpacing.space3),
            const _MapBlock(),
          ],
          if(!started) ...[
            const SizedBox(height: AppSpacing.space3),
            _ActionButton(
              label: 'Start job',
              color: AppColors.green,
              onPressed: state.startProviderWork,
            ),
          ],
          const SizedBox(height: AppSpacing.space3),
          const TextField(
            minLines: 2,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: 'Provider notes',
              hintText: 'Notes about the job',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: AppSpacing.space3),
          _SecondaryButton(
            label: 'Upload photos',
            onPressed: () {
              setState(() {
                photoAttached = true;
              });
            },
          ),
          if(photoAttached) ...[
            const SizedBox(height: AppSpacing.space2),
            Text('Photo attached.', style: Theme.of(context).textTheme.bodyLarge),
          ],
          if(started) ...[
            const SizedBox(height: AppSpacing.space5),
            _ActionButton(
              label: 'Complete job',
              color: AppColors.green,
              onPressed: () {
                state.openCostReview(fromProvider: true);
              },
            ),
          ],
        ],
      ),
    );
  }
}

class _MapBlock extends StatelessWidget {
  const _MapBlock();

  @override
  Widget build(BuildContext context) {
    return Container(
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
    );
  }
}

class _SecondaryButton extends StatelessWidget {
  const _SecondaryButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.blue,
          side: const BorderSide(color: AppColors.line),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
        ),
        child: Text(label),
      ),
    );
  }
}

class _UserTabBar extends StatelessWidget {
  const _UserTabBar({required this.current, this.frosted = false});

  final _UserTab current;
  final bool frosted;

  @override
  Widget build(BuildContext context) {
    final blur = frosted;
    final bar = NavigationBarTheme(
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
      elevation: blur ? 0 : null,
      surfaceTintColor: blur ? Colors.transparent : null,
      shadowColor: blur ? Colors.transparent : null,
      backgroundColor: blur ? const Color(0xB8FFFFFF) : AppColors.surface,
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
          icon: Icon(Icons.person),
          label: 'Profile',
        ),
      ],
      ),
    );
    if(!blur) {
      return bar;
    }
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: DecoratedBox(
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: Color(0x66FFFFFF))),
          ),
          child: bar,
        ),
      ),
    );
  }
}

class _FlowFrame extends StatelessWidget {
  const _FlowFrame({
    required this.child,
    this.title,
    this.onBack,
    this.onTitle,
    this.emergency = false,
    this.tab,
    this.plainChrome = false,
    this.fill = false,
  });

  final Widget child;
  final String? title;
  final VoidCallback? onBack;
  final VoidCallback? onTitle;
  final bool emergency;
  final _UserTab? tab;
  final bool plainChrome;
  final bool fill;

  TextStyle? titleStyle(BuildContext context) {
    return Theme.of(context).textTheme.labelLarge?.copyWith(
      color: plainChrome ? AppColors.ink : AppColors.blue,
      fontWeight: plainChrome ? FontWeight.w600 : FontWeight.w700,
      letterSpacing: plainChrome ? -0.2 : 0,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: plainChrome ? const Color(0xFFF2F2F7) : AppColors.soft,
      bottomNavigationBar: tab == null
          ? null
          : _UserTabBar(current: tab!, frosted: plainChrome),
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
                      child: onTitle == null
                          ? Text(
                              title!,
                              textAlign: onBack == null
                                  ? TextAlign.center
                                  : TextAlign.left,
                              style: titleStyle(context),
                            )
                          : InkWell(
                              onTap: onTitle,
                              borderRadius: BorderRadius.circular(AppRadius.sm),
                              child: SizedBox(
                                height: 44,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Flexible(
                                      child: Text(
                                        title!,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: titleStyle(context),
                                      ),
                                    ),
                                    const Icon(
                                      Icons.expand_more_rounded,
                                      size: 20,
                                      color: AppColors.muted,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
              ),
            Expanded(
              child: fill
                  ? CustomScrollView(
                      slivers: [
                        SliverFillRemaining(
                          hasScrollBody: false,
                          child: Padding(
                            padding: const EdgeInsets.all(AppSpacing.space4),
                            child: child,
                          ),
                        ),
                      ],
                    )
                  : SingleChildScrollView(
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
  final VoidCallback? onPressed;
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
    this.quiet = false,
    this.emphasis = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;
  final bool quiet;
  final bool emphasis;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(quiet ? 16 : AppRadius.md);
    final card = Material(
      color: AppColors.surface,
      borderRadius: radius,
      child: InkWell(
        borderRadius: radius,
        onTap: onTap,
        child: Container(
          constraints: BoxConstraints(minHeight: emphasis ? 104 : 88),
          padding: const EdgeInsets.all(AppSpacing.space4),
          decoration: BoxDecoration(
            border: quiet ? null : Border.all(color: color, width: 2),
            borderRadius: radius,
          ),
          child: Row(
            children: [
              if(quiet)
                Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: emphasis ? 0.2 : 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 24),
                )
              else
                Icon(icon, color: color, size: 34),
              const SizedBox(width: AppSpacing.space3),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        letterSpacing: quiet ? -0.3 : 0,
                      ),
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
    if(!quiet) {
      return card;
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: const [
          BoxShadow(
            color: Color(0x1417212F),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: card,
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

LatLng _pointAlongRoute(List<LatLng> points, double fraction) {
  const distance = Distance(roundResult: false);
  final segments = <double>[];
  var total = 0.0;
  for(var i = 0; i < points.length - 1; i++) {
    final length = distance(points[i], points[i + 1]).toDouble();
    segments.add(length);
    total += length;
  }
  if(points.length == 1 || total == 0) {
    return points.first;
  }
  var target = fraction * total;
  for(var i = 0; i < segments.length; i++) {
    if(target <= segments[i] || i == segments.length - 1) {
      final t = segments[i] == 0 ? 0.0 : (target / segments[i]).clamp(0.0, 1.0);
      final a = points[i];
      final b = points[i + 1];
      return LatLng(
        a.latitude + ((b.latitude - a.latitude) * t),
        a.longitude + ((b.longitude - a.longitude) * t),
      );
    }
    target -= segments[i];
  }
  return points.last;
}

class _TripMap extends StatefulWidget {
  const _TripMap();

  @override
  State<_TripMap> createState() => _TripMapState();
}

class _TripMapState extends State<_TripMap> {
  final _mapController = MapController();
  bool _mapReady = false;

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<EmergencyRequestState>();
    final fromLat = state.routeFromLat;
    final fromLng = state.routeFromLng;
    final toLat = state.routeToLat;
    final toLng = state.routeToLng;
    if(fromLat == null || fromLng == null || toLat == null || toLng == null) {
      _mapReady = false;
      final hereLat = state.driverAmbulanceLat;
      final hereLng = state.driverAmbulanceLng;
      if(hereLat != null && hereLng != null) {
        final here = LatLng(hereLat, hereLng);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.md),
              child: Container(
                height: 190,
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.line, width: 2),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: FlutterMap(
                  options: MapOptions(initialCenter: here, initialZoom: 16),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.madadplus.madad_plus_mobile',
                      tileProvider: Platform.environment['FLUTTER_TEST'] == 'true'
                          ? _TestTileProvider()
                          : NetworkTileProvider(),
                    ),
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: here,
                          width: 41,
                          height: 41,
                          child: Image.asset(
                            'assets/ambulance.png',
                            width: 41,
                            height: 41,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            if(state.routeError != null) ...[
              const SizedBox(height: AppSpacing.space3),
              _ErrorNotice(message: state.routeError!),
            ],
          ],
        );
      }
      return Column(
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
          if(state.routeError != null) ...[
            const SizedBox(height: AppSpacing.space3),
            _ErrorNotice(message: state.routeError!),
          ],
        ],
      );
    }

    final start = LatLng(fromLat, fromLng);
    final destination = LatLng(toLat, toLng);
    final points = state.routePoints ?? [start, destination];
    final ambulance = _pointAlongRoute(points, state.routeProgress());
    if(_mapReady) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if(mounted && _mapReady) {
          _mapController.move(ambulance, 15);
        }
      });
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        height: 190,
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.line, width: 2),
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: ambulance,
            initialZoom: 15,
            onMapReady: () {
              _mapReady = true;
            },
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.madadplus.madad_plus_mobile',
              tileProvider: Platform.environment['FLUTTER_TEST'] == 'true'
                  ? _TestTileProvider()
                  : NetworkTileProvider(),
            ),
            PolylineLayer(
              polylines: [
                Polyline(
                  points: points,
                  strokeWidth: 4,
                  color: AppColors.blue,
                ),
              ],
            ),
            MarkerLayer(
              markers: [
                Marker(
                  point: ambulance,
                  width: 41,
                  height: 41,
                  child: Image.asset(
                    'assets/ambulance.png',
                    width: 41,
                    height: 41,
                  ),
                ),
                Marker(
                  point: destination,
                  width: 36,
                  height: 36,
                  child: const Icon(
                    Icons.location_on,
                    color: AppColors.blue,
                    size: 36,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
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
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1417212F),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Text('•', style: Theme.of(context).textTheme.headlineSmall),
    );
  }
}

class _MarkPlate extends StatelessWidget {
  const _MarkPlate({
    required this.icon,
    required this.color,
    this.alignment = Alignment.centerLeft,
  });

  final IconData icon;
  final Color color;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: Container(
        width: 88,
        height: 88,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(28),
        ),
        child: Icon(icon, color: color, size: 44),
      ),
    );
  }
}

class _SoftArrive extends StatefulWidget {
  const _SoftArrive({required this.child});

  final Widget child;

  @override
  State<_SoftArrive> createState() => _SoftArriveState();
}

class _SoftArriveState extends State<_SoftArrive>
    with SingleTickerProviderStateMixin {
  late final AnimationController motion;

  @override
  void initState() {
    super.initState();
    motion = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if(!mounted) {
        return;
      }
      if(MediaQuery.disableAnimationsOf(context)) {
        motion.duration = const Duration(milliseconds: 200);
      }
      motion.forward();
    });
  }

  @override
  void dispose() {
    motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return AnimatedBuilder(
      animation: motion,
      builder: (context, child) {
        final t = Curves.easeOutCubic.transform(motion.value);
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, reduceMotion ? 0 : (1 - t) * 8),
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}

class _PressScale extends StatefulWidget {
  const _PressScale({required this.child});

  final Widget child;

  @override
  State<_PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<_PressScale> {
  var pressed = false;

  void release() {
    if(pressed) {
      setState(() {
        pressed = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return Listener(
      onPointerDown: (_) {
        if(!reduceMotion) {
          setState(() {
            pressed = true;
          });
        }
      },
      onPointerUp: (_) {
        release();
      },
      onPointerCancel: (_) {
        release();
      },
      child: AnimatedScale(
        scale: !reduceMotion && pressed ? 0.97 : 1,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

class _GroupedLink {
  const _GroupedLink(this.label, this.onPressed);

  final String label;
  final VoidCallback onPressed;
}

class _GroupedLinks extends StatelessWidget {
  const _GroupedLinks({required this.links});

  final List<_GroupedLink> links;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for(var index = 0; index < links.length; index++) ...[
            _PressScale(
              child: SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: links[index].onPressed,
                  child: Text(links[index].label),
                ),
              ),
            ),
            if(index != links.length - 1)
              const Divider(height: 1, thickness: 1, color: AppColors.line),
          ],
        ],
      ),
    );
  }
}

class _InsetGroup extends StatelessWidget {
  const _InsetGroup({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for(var index = 0; index < children.length; index++) ...[
            children[index],
            if(index != children.length - 1)
              const Divider(height: 1, thickness: 1, color: AppColors.line),
          ],
        ],
      ),
    );
  }
}

class _InsetRow extends StatelessWidget {
  const _InsetRow({
    required this.label,
    required this.onPressed,
    this.showChevron = true,
  });

  final String label;
  final VoidCallback onPressed;
  final bool showChevron;

  @override
  Widget build(BuildContext context) {
    final text = Text(
      label,
      style: Theme.of(context).textTheme.labelLarge?.copyWith(
        color: showChevron ? AppColors.ink : AppColors.blue,
        fontWeight: FontWeight.w600,
        height: 1.3,
      ),
    );
    return InkWell(
      onTap: onPressed,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 52),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.space4),
          child: showChevron
              ? Row(
                  children: [
                    Expanded(child: text),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: AppColors.muted,
                      size: 22,
                    ),
                  ],
                )
              : Center(child: text),
        ),
      ),
    );
  }
}

