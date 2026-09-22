// import 'dart:convert';
// import 'package:flutter/material.dart';
// import 'package:get/get.dart';
// import 'package:http/http.dart' as http;
// import 'package:google_fonts/google_fonts.dart';
// import 'package:lets_talk_admine/Api/ApiendPoints.dart';

// class ManageLiveLinksScreen extends StatefulWidget {
//   const ManageLiveLinksScreen({super.key});

//   @override
//   State<ManageLiveLinksScreen> createState() => _ManageLiveLinksScreenState();
// }

// class _ManageLiveLinksScreenState extends State<ManageLiveLinksScreen> {
//   String selectedLanguage = "English";
//   String selectedStage = "stage1";
//   String selectedType = "class";

//   final TextEditingController linkController = TextEditingController();
//   bool isUpdating = false;
//   bool isDeleting = false;

//   final Color backgroundColor = const Color(0xff0D0D0D);
//   final Color cardColor = const Color(0xff1E1E1E);
//   final Color accentPurple = const Color(0xff7F56D9);

//   final List<String> allStages = const [
//     "stage1",
//     "stage2",
//     "stage3",
//     "stage4",
//     "stage5",
//     "stage6",
//     "stage7",
//   ];

//   @override
//   void dispose() {
//     linkController.dispose();
//     super.dispose();
//   }

//   Future<void> updateLink() async {
//     final link = linkController.text.trim();

//     if (link.isEmpty) {
//       Get.snackbar(
//         "Missing Link",
//         "Please paste a valid meeting link",
//         backgroundColor: Colors.red.shade800,
//         colorText: Colors.white,
//         snackPosition: SnackPosition.BOTTOM,
//         margin: const EdgeInsets.all(16),
//       );
//       return;
//     }

//     if (!link.startsWith("http://") && !link.startsWith("https://")) {
//       Get.snackbar(
//         "Invalid URL",
//         "Link should start with https:// (e.g., https://meet.google.com/...)",
//         backgroundColor: Colors.amber.shade900,
//         colorText: Colors.white,
//         snackPosition: SnackPosition.BOTTOM,
//         margin: const EdgeInsets.all(16),
//       );
//       return;
//     }

//     setState(() => isUpdating = true);

//     try {
//       final response = await http.post(
//         Uri.parse(ApiEndpoints.updateLiveLink),
//         headers: {"Content-Type": "application/json"},
//         body: jsonEncode({
//           "language": selectedLanguage,
//           "stage": selectedStage,
//           "type": selectedType,
//           "link": link,
//         }),
//       );

//       if (response.statusCode == 200) {
//         Get.snackbar(
//           "Success",
//           "Link is now LIVE for students!",
//           backgroundColor: Colors.green,
//           colorText: Colors.white,
//           snackPosition: SnackPosition.BOTTOM,
//           margin: const EdgeInsets.all(16),
//         );
//         linkController.clear();
//       } else {
//         final data = jsonDecode(response.body);
//         Get.snackbar(
//           "Failed",
//           data['message'] ?? "Could not update meeting link",
//           backgroundColor: Colors.red,
//           colorText: Colors.white,
//           snackPosition: SnackPosition.BOTTOM,
//           margin: const EdgeInsets.all(16),
//         );
//       }
//     } catch (e) {
//       Get.snackbar(
//         "Error",
//         "Failed to connect to server",
//         backgroundColor: Colors.red,
//         colorText: Colors.white,
//         snackPosition: SnackPosition.BOTTOM,
//         margin: const EdgeInsets.all(16),
//       );
//     } finally {
//       setState(() => isUpdating = false);
//     }
//   }

//   Future<void> deleteLink() async {
//     Get.defaultDialog(
//       title: "Remove Live Link?",
//       middleText:
//           "Are you sure you want to remove the active link for $selectedLanguage (${selectedStage.toUpperCase()} - ${selectedType.toUpperCase()})?",
//       textConfirm: "Remove",
//       textCancel: "Cancel",
//       confirmTextColor: Colors.white,
//       buttonColor: Colors.red,
//       backgroundColor: cardColor,
//       titleStyle: const TextStyle(color: Colors.white),
//       middleTextStyle: const TextStyle(color: Colors.white70),
//       onConfirm: () async {
//         Get.back();
//         setState(() => isDeleting = true);

//         try {
//           final request = http.Request(
//             "DELETE",
//             Uri.parse(ApiEndpoints.deleteLiveLink),
//           );
//           request.headers.addAll({"Content-Type": "application/json"});
//           request.body = jsonEncode({
//             "language": selectedLanguage,
//             "stage": selectedStage,
//             "type": selectedType,
//           });

//           final streamedResponse = await request.send();
//           final response = await http.Response.fromStream(streamedResponse);

//           if (response.statusCode == 200) {
//             Get.snackbar(
//               "Removed",
//               "Meeting link removed successfully",
//               backgroundColor: Colors.orange,
//               colorText: Colors.white,
//               snackPosition: SnackPosition.BOTTOM,
//               margin: const EdgeInsets.all(16),
//             );
//           } else {
//             Get.snackbar(
//               "Error",
//               "Failed to remove link",
//               backgroundColor: Colors.red,
//               colorText: Colors.white,
//               snackPosition: SnackPosition.BOTTOM,
//               margin: const EdgeInsets.all(16),
//             );
//           }
//         } catch (e) {
//           Get.snackbar(
//             "Error",
//             "Connection failed while deleting",
//             backgroundColor: Colors.red,
//             colorText: Colors.white,
//             snackPosition: SnackPosition.BOTTOM,
//             margin: const EdgeInsets.all(16),
//           );
//         } finally {
//           setState(() => isDeleting = false);
//         }
//       },
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     final screenWidth = MediaQuery.of(context).size.width;
//     final isDesktop = screenWidth >= 900;
//     final isTablet = screenWidth >= 600 && screenWidth < 900;

//     return Scaffold(
//       backgroundColor: backgroundColor,
//       appBar: AppBar(
//         backgroundColor: cardColor,
//         elevation: 0,
//         leading: IconButton(
//           icon: const Icon(
//             Icons.arrow_back_ios_new_rounded,
//             color: Colors.white,
//             size: 20,
//           ),
//           onPressed: () => Get.back(),
//         ),
//         title: Text(
//           "Live Class Manager",
//           style: GoogleFonts.poppins(
//             color: Colors.white,
//             fontWeight: FontWeight.bold,
//             fontSize: isDesktop ? 22 : 18,
//           ),
//         ),
//       ),
//       body: SafeArea(
//         child: Center(
//           child: ConstrainedBox(
//             constraints: const BoxConstraints(maxWidth: 800),
//             child: SingleChildScrollView(
//               padding: EdgeInsets.symmetric(
//                 horizontal: isDesktop ? 32.0 : (isTablet ? 24.0 : 16.0),
//                 vertical: 20.0,
//               ),
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   _buildBroadcastBanner(),
//                   const SizedBox(height: 24),
//                   Container(
//                     padding: const EdgeInsets.all(24),
//                     decoration: BoxDecoration(
//                       color: cardColor,
//                       borderRadius: BorderRadius.circular(16),
//                       border: Border.all(color: Colors.white10),
//                     ),
//                     child: Column(
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       children: [
//                         Text(
//                           "Class Configuration",
//                           style: GoogleFonts.poppins(
//                             color: Colors.white,
//                             fontSize: 16,
//                             fontWeight: FontWeight.bold,
//                           ),
//                         ),
//                         const SizedBox(height: 20),
//                         Row(
//                           children: [
//                             Expanded(
//                               child: _buildDropdownField(
//                                 label: "Course Language",
//                                 icon: Icons.language_rounded,
//                                 value: selectedLanguage,
//                                 items: const ["English", "Hindi"],
//                                 onChanged: (val) =>
//                                     setState(() => selectedLanguage = val!),
//                               ),
//                             ),
//                             const SizedBox(width: 14),
//                             Expanded(
//                               child: _buildDropdownField(
//                                 label: "Target Stage",
//                                 icon: Icons.stairs_rounded,
//                                 value: selectedStage,
//                                 items: allStages,
//                                 onChanged: (val) =>
//                                     setState(() => selectedStage = val!),
//                               ),
//                             ),
//                           ],
//                         ),
//                         const SizedBox(height: 24),
//                         Text(
//                           "Session Format",
//                           style: GoogleFonts.poppins(
//                             color: Colors.white70,
//                             fontSize: 13,
//                             fontWeight: FontWeight.w500,
//                           ),
//                         ),
//                         const SizedBox(height: 10),
//                         Row(
//                           children: [
//                             Expanded(
//                               child: _buildTypeCard(
//                                 title: "Regular Class",
//                                 subtitle: "Curriculum Lecture",
//                                 typeValue: "class",
//                                 icon: Icons.school_rounded,
//                               ),
//                             ),
//                             const SizedBox(width: 12),
//                             Expanded(
//                               child: _buildTypeCard(
//                                 title: "Speaking Club",
//                                 subtitle: "Practice Session",
//                                 typeValue: "club",
//                                 icon: Icons.forum_rounded,
//                               ),
//                             ),
//                           ],
//                         ),
//                         const Divider(color: Colors.white10, height: 36),
//                         Text(
//                           "Meeting URL",
//                           style: GoogleFonts.poppins(
//                             color: Colors.white70,
//                             fontSize: 13,
//                             fontWeight: FontWeight.w500,
//                           ),
//                         ),
//                         const SizedBox(height: 10),
//                         TextField(
//                           controller: linkController,
//                           keyboardType: TextInputType.url,
//                           style: const TextStyle(
//                             color: Colors.white,
//                             fontSize: 14,
//                           ),
//                           decoration: InputDecoration(
//                             hintText: "https://meet.google.com/abc-defg-hij",
//                             hintStyle: const TextStyle(
//                               color: Colors.grey,
//                               fontSize: 13,
//                             ),
//                             prefixIcon: const Icon(
//                               Icons.videocam_outlined,
//                               color: Colors.grey,
//                             ),
//                             suffixIcon: IconButton(
//                               icon: const Icon(
//                                 Icons.clear_rounded,
//                                 color: Colors.grey,
//                                 size: 18,
//                               ),
//                               onPressed: () => linkController.clear(),
//                             ),
//                             filled: true,
//                             fillColor: const Color(0xff141414),
//                             border: OutlineInputBorder(
//                               borderRadius: BorderRadius.circular(12),
//                               borderSide: BorderSide.none,
//                             ),
//                             focusedBorder: OutlineInputBorder(
//                               borderRadius: BorderRadius.circular(12),
//                               borderSide: BorderSide(
//                                 color: accentPurple,
//                                 width: 1.5,
//                               ),
//                             ),
//                           ),
//                         ),
//                         const SizedBox(height: 28),
//                         SizedBox(
//                           width: double.infinity,
//                           height: 52,
//                           child: ElevatedButton.icon(
//                             onPressed: isUpdating ? null : updateLink,
//                             icon: isUpdating
//                                 ? const SizedBox(
//                                     height: 20,
//                                     width: 20,
//                                     child: CircularProgressIndicator(
//                                       strokeWidth: 2,
//                                       color: Colors.white,
//                                     ),
//                                   )
//                                 : const Icon(
//                                     Icons.sensors_rounded,
//                                     color: Colors.white,
//                                   ),
//                             label: Text(
//                               isUpdating
//                                   ? "PUBLISHING..."
//                                   : "BROADCAST LIVE LINK",
//                               style: GoogleFonts.poppins(
//                                 color: Colors.white,
//                                 fontWeight: FontWeight.bold,
//                                 fontSize: 15,
//                               ),
//                             ),
//                             style: ElevatedButton.styleFrom(
//                               backgroundColor: accentPurple,
//                               shape: RoundedRectangleBorder(
//                                 borderRadius: BorderRadius.circular(12),
//                               ),
//                             ),
//                           ),
//                         ),
//                         const SizedBox(height: 12),
//                         Center(
//                           child: TextButton.icon(
//                             onPressed: isDeleting ? null : deleteLink,
//                             icon: isDeleting
//                                 ? const SizedBox(
//                                     width: 14,
//                                     height: 14,
//                                     child: CircularProgressIndicator(
//                                       strokeWidth: 1.5,
//                                       color: Colors.redAccent,
//                                     ),
//                                   )
//                                 : const Icon(
//                                     Icons.delete_outline_rounded,
//                                     color: Colors.redAccent,
//                                     size: 18,
//                                   ),
//                             label: Text(
//                               "Remove Active Link for this Stage",
//                               style: GoogleFonts.poppins(
//                                 color: Colors.redAccent,
//                                 fontSize: 13,
//                                 fontWeight: FontWeight.w500,
//                               ),
//                             ),
//                           ),
//                         ),
//                       ],
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//           ),
//         ),
//       ),
//     );
//   }

//   Widget _buildBroadcastBanner() {
//     return Container(
//       padding: const EdgeInsets.all(16),
//       decoration: BoxDecoration(
//         color: accentPurple.withOpacity(0.12),
//         borderRadius: BorderRadius.circular(16),
//         border: Border.all(color: accentPurple.withOpacity(0.3)),
//       ),
//       child: Row(
//         children: [
//           Container(
//             padding: const EdgeInsets.all(10),
//             decoration: BoxDecoration(
//               color: accentPurple.withOpacity(0.2),
//               shape: BoxShape.circle,
//             ),
//             child: Icon(Icons.live_tv_rounded, color: accentPurple, size: 24),
//           ),
//           const SizedBox(width: 14),
//           Expanded(
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Text(
//                   "Active Target Channel",
//                   style: GoogleFonts.poppins(
//                     color: Colors.white70,
//                     fontSize: 12,
//                     fontWeight: FontWeight.w500,
//                   ),
//                 ),
//                 const SizedBox(height: 2),
//                 Text(
//                   "$selectedLanguage • ${selectedStage.toUpperCase()} • ${selectedType == 'class' ? 'Regular Class' : 'Speaking Club'}",
//                   style: GoogleFonts.poppins(
//                     color: Colors.white,
//                     fontSize: 15,
//                     fontWeight: FontWeight.bold,
//                   ),
//                 ),
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildDropdownField({
//     required String label,
//     required IconData icon,
//     required String value,
//     required List<String> items,
//     required ValueChanged<String?> onChanged,
//   }) {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Text(
//           label,
//           style: GoogleFonts.poppins(
//             color: Colors.white70,
//             fontSize: 13,
//             fontWeight: FontWeight.w500,
//           ),
//         ),
//         const SizedBox(height: 8),
//         DropdownButtonFormField<String>(
//           value: value,
//           dropdownColor: const Color(0xff252525),
//           items: items
//               .map(
//                 (e) => DropdownMenuItem(
//                   value: e,
//                   child: Text(
//                     e.toUpperCase(),
//                     style: const TextStyle(color: Colors.white, fontSize: 13),
//                   ),
//                 ),
//               )
//               .toList(),
//           onChanged: onChanged,
//           decoration: InputDecoration(
//             prefixIcon: Icon(icon, color: Colors.grey, size: 18),
//             filled: true,
//             fillColor: const Color(0xff141414),
//             border: OutlineInputBorder(
//               borderRadius: BorderRadius.circular(12),
//               borderSide: BorderSide.none,
//             ),
//           ),
//         ),
//       ],
//     );
//   }

//   Widget _buildTypeCard({
//     required String title,
//     required String subtitle,
//     required String typeValue,
//     required IconData icon,
//   }) {
//     final bool isSelected = selectedType == typeValue;

//     return Material(
//       color: Colors.transparent,
//       child: InkWell(
//         onTap: () => setState(() => selectedType = typeValue),
//         borderRadius: BorderRadius.circular(12),
//         child: Container(
//           padding: const EdgeInsets.all(14),
//           decoration: BoxDecoration(
//             color: isSelected
//                 ? accentPurple.withOpacity(0.15)
//                 : const Color(0xff141414),
//             borderRadius: BorderRadius.circular(12),
//             border: Border.all(
//               color: isSelected ? accentPurple : Colors.transparent,
//               width: 1.5,
//             ),
//           ),
//           child: Row(
//             children: [
//               Icon(
//                 icon,
//                 color: isSelected ? accentPurple : Colors.grey,
//                 size: 24,
//               ),
//               const SizedBox(width: 12),
//               Expanded(
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     Text(
//                       title,
//                       style: GoogleFonts.poppins(
//                         color: Colors.white,
//                         fontSize: 13,
//                         fontWeight: FontWeight.w600,
//                       ),
//                     ),
//                     Text(
//                       subtitle,
//                       style: GoogleFonts.poppins(
//                         color: Colors.grey,
//                         fontSize: 11,
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }