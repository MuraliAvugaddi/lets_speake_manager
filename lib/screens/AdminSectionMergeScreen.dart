import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:get/get.dart';
import 'package:lets_speake_manager/Api/ApiendPoints.dart';
import 'package:lets_speake_manager/Navigation/AdminShellNavigation.dart';

class AdminSectionMergeScreen extends StatefulWidget {
  const AdminSectionMergeScreen({super.key});

  @override
  State<AdminSectionMergeScreen> createState() =>
      _AdminSectionMergeScreenState();
}

class _AdminSectionMergeScreenState
    extends State<AdminSectionMergeScreen> {
  // ============================================================
  // LET'S SPEAK LIGHT COLORS
  // ============================================================

  static const Color primaryBlue = Color(0xFF2563EB);
  static const Color darkBlue = Color(0xFF1D4ED8);

  static const Color lightBlue = Color(0xFFE7F2F8);
  static const Color paleBlue = Color(0xFFF5F9FF);

  static const Color background = Color(0xFFEAF4FA);
  static const Color cardColor = Colors.white;

  static const Color textPrimary = Color(0xFF173E5C);
  static const Color textSecondary = Color(0xFF6A8295);

  static const Color borderColor = Color(0xFFD7E7F0);

  static const Color successColor = Color(0xFF16A34A);
  static const Color dangerColor = Color(0xFFDC2626);
  static const Color warningColor = Color(0xFFD97706);

  // ============================================================
  // STATE
  // ============================================================

  bool isLoading = false;
  bool isSubmitting = false;

  String? cancellingMergeId;

  List<dynamic> activeMerges = [];

  String selectedStage = 'stage1';
  String hostSection = 'A';
  String guestSection = 'B';
  String language = 'English';

  final List<String> sections = [
    'A',
    'B',
    'C',
    'D',
    'E',
  ];

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();
    fetchActiveMerges();
  }

  // ============================================================
  // FETCH ACTIVE MERGES
  // ============================================================

  Future<void> fetchActiveMerges() async {
    if (!mounted) return;

    setState(() {
      isLoading = true;
    });

    try {
      final response = await http.get(
        Uri.parse(ApiEndpoints.sectionMerges),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (!mounted) return;

        setState(() {
          activeMerges = data['merges'] ?? [];
        });
      } else {
        _showSnackbar(
          title: 'Unable to Load',
          message: 'Could not fetch active section merges.',
          color: warningColor,
        );
      }
    } catch (e) {
      debugPrint('Fetch merges error: $e');

      if (mounted) {
        _showSnackbar(
          title: 'Connection Error',
          message: 'Unable to connect to the server.',
          color: dangerColor,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  // ============================================================
  // SUBMIT MERGE
  // ============================================================

  Future<void> _submitMerge() async {
    if (language == 'English' && hostSection == guestSection) {
      _showSnackbar(
        title: 'Invalid Merge',
        message: 'Host and Guest sections cannot be the same.',
        color: dangerColor,
      );
      return;
    }

    if (isSubmitting) return;

    setState(() {
      isSubmitting = true;
    });

    try {
      final response = await http.post(
        Uri.parse(ApiEndpoints.mergeSections),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'language': language,
          'stage': selectedStage,
          'hostSection': language == 'Hindi' ? 'None' : hostSection,
          'guestSection': language == 'Hindi' ? 'None' : guestSection,
        }),
      );

      if (response.statusCode == 200) {
        _showSnackbar(
          title: 'Merge Created',
          message: language == 'Hindi' ? 'Hindi stage configured successfully.' : 'Sections merged successfully.',
          color: successColor,
        );

        await fetchActiveMerges();
      } else {
        String message = 'Failed to merge sections.';

        try {
          final data = jsonDecode(response.body);
          message = data['message'] ?? message;
        } catch (_) {}

        _showSnackbar(
          title: 'Merge Failed',
          message: message,
          color: warningColor,
        );
      }
    } catch (e) {
      debugPrint('Submit merge error: $e');

      _showSnackbar(
        title: 'Server Error',
        message: 'Unable to connect to the server.',
        color: dangerColor,
      );
    } finally {
      if (mounted) {
        setState(() {
          isSubmitting = false;
        });
      }
    }
  }

  // ============================================================
  // CANCEL MERGE
  // ============================================================

  Future<void> _cancelMerge(String mergeId) async {
    final confirmed = await _showCancelConfirmation();

    if (!confirmed) return;

    if (!mounted) return;

    setState(() {
      cancellingMergeId = mergeId;
    });

    try {
      final response = await http.delete(
        Uri.parse(
          '${ApiEndpoints.baseUrl}/admin/section-merges/$mergeId',
        ),
      );

      if (response.statusCode == 200) {
        _showSnackbar(
          title: 'Merge Cancelled',
          message: 'Section merge reverted successfully.',
          color: primaryBlue,
        );

        await fetchActiveMerges();
      } else {
        _showSnackbar(
          title: 'Unable to Cancel',
          message: 'The merge could not be cancelled.',
          color: dangerColor,
        );
      }
    } catch (e) {
      debugPrint('Cancel merge error: $e');

      _showSnackbar(
        title: 'Connection Error',
        message: 'Unable to connect to the server.',
        color: dangerColor,
      );
    } finally {
      if (mounted) {
        setState(() {
          cancellingMergeId = null;
        });
      }
    }
  }

  // ============================================================
  // CANCEL CONFIRMATION
  // ============================================================

  Future<bool> _showCancelConfirmation() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return Theme(
          data: ThemeData(
            brightness: Brightness.light,
            useMaterial3: true,
            scaffoldBackgroundColor: Colors.white,
            canvasColor: Colors.white,
            cardColor: Colors.white,
            colorScheme: ColorScheme.fromSeed(
              seedColor: primaryBlue,
              brightness: Brightness.light,
            ),
          ),
          child: AlertDialog(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF1F2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.warning_amber_rounded,
                    color: dangerColor,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Cancel Merge?',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            content: Text(
              'This will restore the sections to their normal state.',
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: textSecondary,
                height: 1.5,
              ),
            ),
            actionsPadding: const EdgeInsets.fromLTRB(
              20,
              0,
              20,
              16,
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(
                    dialogContext,
                    false,
                  );
                },
                child: Text(
                  'Keep Merge',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    color: textSecondary,
                  ),
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(
                    dialogContext,
                    true,
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: dangerColor,
                  foregroundColor: Colors.white,
                  surfaceTintColor: Colors.transparent,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Text(
                  'Cancel Merge',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );

    return result ?? false;
  }

  // ============================================================
  // SNACKBAR
  // ============================================================

  void _showSnackbar({
    required String title,
    required String message,
    required Color color,
  }) {
    Get.snackbar(
      title,
      message,
      backgroundColor: color,
      colorText: Colors.white,
      margin: const EdgeInsets.all(16),
      borderRadius: 12,
      duration: const Duration(seconds: 3),
      snackPosition: SnackPosition.TOP,
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ThemeData(
        brightness: Brightness.light,
        useMaterial3: true,
        scaffoldBackgroundColor: background,
        canvasColor: Colors.white,
        cardColor: Colors.white,
        dialogBackgroundColor: Colors.white,
        colorScheme: ColorScheme.fromSeed(
          seedColor: primaryBlue,
          brightness: Brightness.light,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: textPrimary,
          surfaceTintColor: Colors.white,
          elevation: 0,
          scrolledUnderElevation: 0,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.all(
              Radius.circular(11),
            ),
            borderSide: BorderSide(
              color: borderColor,
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.all(
              Radius.circular(11),
            ),
            borderSide: BorderSide(
              color: borderColor,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.all(
              Radius.circular(11),
            ),
            borderSide: BorderSide(
              color: primaryBlue,
              width: 1.4,
            ),
          ),
        ),
      ),
      child: Scaffold(
        backgroundColor: background,
        appBar: _buildAppBar(),
        body: LayoutBuilder(
          builder: (
            context,
            constraints,
          ) {
            final double screenWidth = constraints.maxWidth;

            final bool isDesktop = screenWidth >= 1000;
            final bool isTablet =
                screenWidth >= 600 && screenWidth < 1000;

            return RefreshIndicator(
              color: primaryBlue,
              backgroundColor: Colors.white,
              onRefresh: fetchActiveMerges,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.symmetric(
                  horizontal: isDesktop
                      ? 36
                      : isTablet
                          ? 24
                          : 16,
                  vertical: 24,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: 1250,
                    ),
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        _buildPageHeader(),

                        const SizedBox(height: 24),

                        if (isDesktop)
                          Row(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: 5,
                                child:
                                    _buildCreateMergeCard(),
                              ),
                              const SizedBox(width: 24),
                              Expanded(
                                flex: 4,
                                child:
                                    _buildInformationCard(),
                              ),
                            ],
                          )
                        else if (isTablet)
                          Column(
                            children: [
                              _buildCreateMergeCard(),
                              const SizedBox(height: 20),
                              _buildInformationCard(),
                            ],
                          )
                        else
                          Column(
                            children: [
                              _buildCreateMergeCard(),
                              const SizedBox(height: 20),
                              _buildInformationCard(),
                            ],
                          ),

                        const SizedBox(height: 32),

                        _buildActiveMergeHeader(),

                        const SizedBox(height: 14),

                        _buildActiveMerges(),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    final isMobile = MediaQuery.sizeOf(context).width < 700;

    return PreferredSize(
      // Compact header like the Student Feedback screen.
      preferredSize: Size.fromHeight(isMobile ? 54 : 60),
      child: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(
            bottom: BorderSide(
              color: borderColor,
              width: 1,
            ),
          ),
        ),
        child: Row(
          children: [
            // Clean hamburger icon.
            // No surrounding box and no border.
            SizedBox(
              width: isMobile ? 50 : 58,
              child: Center(
                child: IconButton(
                  tooltip: 'Open menu',
                  onPressed: AdminShellNavigation.openDrawer,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 42,
                    minHeight: 42,
                  ),
                  splashRadius: 20,
                  icon: const Icon(
                    Icons.menu_rounded,
                    color: textPrimary,
                    size: 25,
                  ),
                ),
              ),
            ),

            // Smaller page icon.
            Container(
              width: isMobile ? 34 : 38,
              height: isMobile ? 34 : 38,
              decoration: BoxDecoration(
                color: const Color(0xFF0F5A87),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(
                Icons.merge_type_rounded,
                color: Colors.white,
                size: isMobile ? 18 : 20,
              ),
            ),

            SizedBox(width: isMobile ? 9 : 11),

            // Compact title + subtitle.
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Section Merge',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      color: textPrimary,
                      fontSize: isMobile ? 15 : 18,
                      fontWeight: FontWeight.w700,
                      height: 1.05,
                    ),
                  ),
                  if (!isMobile)
                    Text(
                      'Manage temporary section combinations',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        color: textSecondary,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w500,
                        height: 1.1,
                      ),
                    ),
                ],
              ),
            ),

            // Smaller refresh icon.
            Padding(
              padding: EdgeInsets.only(right: isMobile ? 5 : 9),
              child: IconButton(
                tooltip: 'Refresh',
                onPressed: isLoading ? null : fetchActiveMerges,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(
                  minWidth: 42,
                  minHeight: 42,
                ),
                splashRadius: 20,
                icon: isLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: primaryBlue,
                        ),
                      )
                    : const Icon(
                        Icons.refresh_rounded,
                        color: textPrimary,
                        size: 23,
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPageHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Temporary Section Merging',
          style: GoogleFonts.poppins(
            fontSize: 25,
            fontWeight: FontWeight.w700,
            color: textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Temporarily combine sections when a trainer is unavailable.',
          style: GoogleFonts.poppins(
            fontSize: 13,
            color: textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildCreateMergeCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: borderColor,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.035),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _iconContainer(
                Icons.merge_type_rounded,
                lightBlue,
                primaryBlue,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Create Temporary Merge',
                      style: GoogleFonts.poppins(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Select the sections you want to combine.',
                      style: GoogleFonts.poppins(
                        fontSize: 11.5,
                        color: textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          _buildLabel('Language'),

          const SizedBox(height: 7),

          _buildDropdown(
            value: language,
            items: const [
              'English',
              'Hindi',
            ],
            icon: Icons.language_rounded,
            onChanged: (value) {
              if (value != null) {
                setState(() {
                  language = value;
                });
              }
            },
          ),

          const SizedBox(height: 16),

          _buildLabel('Stage'),

          const SizedBox(height: 7),

          _buildDropdown(
            value: selectedStage,
            items: List.generate(
              7,
              (index) => 'stage${index + 1}',
            ),
            displayText: (value) {
              return value.replaceFirst(
                'stage',
                'Stage ',
              );
            },
            icon: Icons.layers_rounded,
            onChanged: (value) {
              if (value != null) {
                setState(() {
                  selectedStage = value;
                });
              }
            },
          ),

          if (language == 'English') ...[
            const SizedBox(height: 20),

            Text(
              'Section Mapping',
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: textPrimary,
              ),
            ),

            const SizedBox(height: 10),

            LayoutBuilder(
              builder: (
                context,
                constraints,
              ) {
                if (constraints.maxWidth < 550) {
                  return Column(
                    children: [
                      _buildSectionSelector(
                        title: 'Host Section',
                        subtitle: 'Trainer present',
                        value: hostSection,
                        icon: Icons.person_rounded,
                        iconColor: successColor,
                        onChanged: (value) {
                          setState(() {
                            hostSection = value;
                          });
                        },
                      ),
                      const SizedBox(height: 10),
                      _buildMergeArrow(horizontal: false),
                      const SizedBox(height: 10),
                      _buildSectionSelector(
                        title: 'Guest Section',
                        subtitle: 'Trainer absent',
                        value: guestSection,
                        icon: Icons.person_off_rounded,
                        iconColor: warningColor,
                        onChanged: (value) {
                          setState(() {
                            guestSection = value;
                          });
                        },
                      ),
                    ],
                  );
                }

                return Row(
                  children: [
                    Expanded(
                      child: _buildSectionSelector(
                        title: 'Host Section',
                        subtitle: 'Trainer present',
                        value: hostSection,
                        icon: Icons.person_rounded,
                        iconColor: successColor,
                        onChanged: (value) {
                          setState(() {
                            hostSection = value;
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    _buildMergeArrow(),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildSectionSelector(
                        title: 'Guest Section',
                        subtitle: 'Trainer absent',
                        value: guestSection,
                        icon: Icons.person_off_rounded,
                        iconColor: warningColor,
                        onChanged: (value) {
                          setState(() {
                            guestSection = value;
                          });
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ],

          const SizedBox(height: 22),

          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: paleBlue,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFFDCEBFF),
              ),
            ),
            child: Row(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.info_outline_rounded,
                  size: 18,
                  color: primaryBlue,
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    language == 'Hindi'
                        ? 'Hindi classes do not use sections. Merges apply per stage.'
                        : 'Students from the Guest Section will temporarily attend the Host Section.',
                    style: GoogleFonts.poppins(
                      fontSize: 11.5,
                      color: const Color(0xFF36516E),
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed:
                  isSubmitting ? null : _submitMerge,
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryBlue,
                disabledBackgroundColor:
                    primaryBlue.withOpacity(0.55),
                foregroundColor: Colors.white,
                surfaceTintColor: Colors.transparent,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: isSubmitting
                  ? const SizedBox(
                      width: 21,
                      height: 21,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: Colors.white,
                      ),
                    )
                  : Row(
                      mainAxisAlignment:
                          MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.merge_type_rounded,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          language == 'Hindi' ? 'Save Hindi Configuration' : 'Merge Sections',
                          style: GoogleFonts.poppins(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInformationCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: lightBlue,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFD9E9FF),
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _iconContainer(
                Icons.help_outline_rounded,
                Colors.white,
                primaryBlue,
              ),
              const SizedBox(width: 12),
              Text(
                'How it works',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: textPrimary,
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          _buildInfoStep(
            number: '01',
            title: 'Select Language & Stage',
            description:
                'Choose English (with sections) or Hindi (sectionless).',
          ),

          _buildInfoStep(
            number: '02',
            title: 'Section Mapping (English Only)',
            description:
                'For English, assign Host and Guest sections.',
          ),

          _buildInfoStep(
            number: '03',
            title: 'Apply & Save',
            description:
                'Changes apply instantly for live class routing.',
            isLast: true,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoStep({
    required String number,
    required String title,
    required String description,
    bool isLast = false,
  }) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: isLast ? 0 : 18,
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              number,
              style: GoogleFonts.poppins(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: primaryBlue,
              ),
            ),
          ),

          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  description,
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: textSecondary,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveMergeHeader() {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Text(
                'Active Temporary Merges',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: textPrimary,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                'Currently active section combinations.',
                style: GoogleFonts.poppins(
                  fontSize: 11.5,
                  color: textSecondary,
                ),
              ),
            ],
          ),
        ),

        if (!isLoading)
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 11,
              vertical: 6,
            ),
            decoration: BoxDecoration(
              color: lightBlue,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${activeMerges.length} Active',
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: primaryBlue,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildActiveMerges() {
    if (isLoading) {
      return _buildLoadingState();
    }

    if (activeMerges.isEmpty) {
      return _buildEmptyState();
    }

    return LayoutBuilder(
      builder: (
        context,
        constraints,
      ) {
        final double width = constraints.maxWidth;

        if (width >= 1000) {
          final double cardWidth = (width - 16) / 2;
          return Wrap(
            spacing: 16,
            runSpacing: 16,
            children: activeMerges.map((merge) {
              return SizedBox(
                width: cardWidth,
                child: _buildMergeCard(merge),
              );
            }).toList(),
          );
        }

        if (width >= 650) {
          final double cardWidth = (width - 16) / 2;
          return Wrap(
            spacing: 16,
            runSpacing: 16,
            children: activeMerges.map((merge) {
              return SizedBox(
                width: cardWidth,
                child: _buildMergeCard(merge),
              );
            }).toList(),
          );
        }

        return Column(
          children: activeMerges.map((merge) {
            return Padding(
              padding: const EdgeInsets.only(
                bottom: 12,
              ),
              child: _buildMergeCard(merge),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildMergeCard(
    dynamic merge,
  ) {
    final String stage = (merge['stage'] ?? '').toString();
    final String mergeLanguage = (merge['language'] ?? '').toString();
    final String host = (merge['hostSection'] ?? '').toString();
    final String guest = (merge['guestSection'] ?? '').toString();
    final String mergeId = (merge['_id'] ?? '').toString();
    final bool isCancelling = cancellingMergeId == mergeId;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: borderColor,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.025),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _iconContainer(
                Icons.merge_type_rounded,
                lightBlue,
                primaryBlue,
                size: 42,
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      stage.isEmpty
                          ? 'Stage'
                          : stage.replaceFirst('stage', 'Stage '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      mergeLanguage,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontSize: 10.5,
                        color: textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF3),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: successColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'Active',
                      style: GoogleFonts.poppins(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                        color: successColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (mergeLanguage == 'English')
            LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth < 400) {
                  return Column(
                    children: [
                      _buildMergeSection(
                        label: 'Guest',
                        section: guest,
                        color: warningColor,
                        backgroundColor: const Color(0xFFFFF7ED),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: 32,
                        height: 32,
                        alignment: Alignment.center,
                        decoration: const BoxDecoration(
                          color: lightBlue,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.arrow_downward_rounded,
                          size: 17,
                          color: primaryBlue,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildMergeSection(
                        label: 'Host',
                        section: host,
                        color: successColor,
                        backgroundColor: const Color(0xFFECFDF3),
                      ),
                    ],
                  );
                }
                return Row(
                  children: [
                    Expanded(
                      child: _buildMergeSection(
                        label: 'Guest',
                        section: guest,
                        color: warningColor,
                        backgroundColor: const Color(0xFFFFF7ED),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 32,
                      height: 32,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                        color: lightBlue,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.arrow_forward_rounded,
                        size: 17,
                        color: primaryBlue,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildMergeSection(
                        label: 'Host',
                        section: host,
                        color: successColor,
                        backgroundColor: const Color(0xFFECFDF3),
                      ),
                    ),
                  ],
                );
              },
            )
          else
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: paleBlue,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'Hindi Class (No sections applicable)',
                style: GoogleFonts.poppins(fontSize: 11, color: textSecondary),
              ),
            ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 40,
            child: OutlinedButton(
              onPressed: isCancelling ? null : () => _cancelMerge(mergeId),
              style: OutlinedButton.styleFrom(
                foregroundColor: dangerColor,
                disabledForegroundColor: dangerColor.withOpacity(0.5),
                side: BorderSide(
                  color: dangerColor.withOpacity(0.25),
                ),
                backgroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: isCancelling
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: dangerColor,
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.close_rounded,
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Cancel Merge',
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMergeSection({
    required String label,
    required String section,
    required Color color,
    required Color backgroundColor,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 10,
      ),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              section.isEmpty ? '-' : section,
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: 9,
                    color: textSecondary,
                  ),
                ),
                Text(
                  section.isEmpty ? 'Section' : 'Section $section',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionSelector({
    required String title,
    required String subtitle,
    required String value,
    required IconData icon,
    required Color iconColor,
    required Function(String) onChanged,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFBFD),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: borderColor,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                size: 17,
                color: iconColor,
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: GoogleFonts.poppins(
              fontSize: 9.5,
              color: textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: value,
            isExpanded: true,
            dropdownColor: Colors.white,
            borderRadius: BorderRadius.circular(12),
            icon: const Icon(
              Icons.keyboard_arrow_down_rounded,
              color: textSecondary,
            ),
            style: GoogleFonts.poppins(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: textPrimary,
            ),
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 11,
                vertical: 11,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(9),
                borderSide: const BorderSide(
                  color: borderColor,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(9),
                borderSide: const BorderSide(
                  color: borderColor,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(9),
                borderSide: const BorderSide(
                  color: primaryBlue,
                  width: 1.4,
                ),
              ),
            ),
            items: sections.map(
              (section) {
                return DropdownMenuItem<String>(
                  value: section,
                  child: Text(
                    'Section $section',
                    style: GoogleFonts.poppins(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: textPrimary,
                    ),
                  ),
                );
              },
            ).toList(),
            onChanged: (value) {
              if (value != null) {
                onChanged(value);
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDropdown({
    required String value,
    required List<String> items,
    required IconData icon,
    required Function(String?) onChanged,
    String Function(String)? displayText,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      isExpanded: true,
      dropdownColor: Colors.white,
      borderRadius: BorderRadius.circular(12),
      icon: const Icon(
        Icons.keyboard_arrow_down_rounded,
        color: textSecondary,
      ),
      style: GoogleFonts.poppins(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: textPrimary,
      ),
      decoration: InputDecoration(
        prefixIcon: Icon(
          icon,
          size: 19,
          color: primaryBlue,
        ),
        filled: true,
        fillColor: const Color(0xFFFAFBFD),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(11),
          borderSide: const BorderSide(
            color: borderColor,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(11),
          borderSide: const BorderSide(
            color: borderColor,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(11),
          borderSide: const BorderSide(
            color: primaryBlue,
            width: 1.4,
          ),
        ),
      ),
      items: items.map(
        (item) {
          return DropdownMenuItem<String>(
            value: item,
            child: Text(
              displayText?.call(item) ?? item,
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: textPrimary,
              ),
            ),
          );
        },
      ).toList(),
      onChanged: onChanged,
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: GoogleFonts.poppins(
        fontSize: 11.5,
        fontWeight: FontWeight.w600,
        color: textPrimary,
      ),
    );
  }

  Widget _iconContainer(
    IconData icon,
    Color backgroundColor,
    Color iconColor, {
    double size = 44,
  }) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(
        icon,
        color: iconColor,
        size: size * 0.48,
      ),
    );
  }

  Widget _buildMergeArrow({
    bool horizontal = true,
  }) {
    return Container(
      width: 38,
      height: 38,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: lightBlue,
        shape: BoxShape.circle,
      ),
      child: Icon(
        horizontal
            ? Icons.arrow_forward_rounded
            : Icons.arrow_downward_rounded,
        size: 18,
        color: primaryBlue,
      ),
    );
  }

  Widget _buildLoadingState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        vertical: 50,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: borderColor,
        ),
      ),
      child: Column(
        children: [
          const SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: primaryBlue,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Loading active merges...',
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        vertical: 45,
        horizontal: 20,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: borderColor,
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 62,
            height: 62,
            decoration: BoxDecoration(
              color: lightBlue,
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(
              Icons.merge_type_rounded,
              size: 30,
              color: primaryBlue,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'No Active Merges',
            style: GoogleFonts.poppins(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: textPrimary,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            'There are currently no temporary section merges.',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 11.5,
              color: textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}