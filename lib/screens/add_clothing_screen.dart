import 'dart:io';

import '../models/clothing_item.dart';
import '../services/database_service.dart';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class AddClothingScreen extends StatefulWidget {
  const AddClothingScreen({super.key});

  @override
  State<AddClothingScreen> createState() => _AddClothingScreenState();
}

class _AddClothingScreenState extends State<AddClothingScreen> {
  final TextEditingController nameController = TextEditingController();

  final TextEditingController categoryController = TextEditingController();

  File? selectedImage;

  String selectedMood = 'Casual';

  final List<String> moods = [
    'Casual',
    'Cozy',
    'Classy',
    'Clean Girl',
    'Soft Girl',
    'Streetwear',
    'Minimal',
    'Dark Academia',
    'Feminine',
    'Chic',
    'Vintage',
    'Sporty',
    'Edgy',
    'Artsy',
    'Modest',
  ];

  Future<void> pickImage() async {
    final picker = ImagePicker();

    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      setState(() {
        selectedImage = File(image.path);
      });
    }
  }

  Future<void> saveItem() async {
    if (selectedImage == null ||
        nameController.text.isEmpty ||
        categoryController.text.isEmpty) {
      return;
    }

    final item = ClothingItem(
      name: nameController.text,
      category: categoryController.text,
      imagePath: selectedImage!.path,
      mood: selectedMood,
    );

    await DatabaseService.insertClothing(item);

    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Clothing')),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,

          children: [
            // image picker
            GestureDetector(
              onTap: pickImage,

              child: Container(
                height: 250,
                width: double.infinity,

                decoration: BoxDecoration(
                  color: Colors.grey.shade200,

                  borderRadius: BorderRadius.circular(20),
                ),

                child: selectedImage == null
                    ? const Column(
                        mainAxisAlignment: MainAxisAlignment.center,

                        children: [
                          Icon(Icons.add_a_photo, size: 50),

                          SizedBox(height: 10),

                          Text('Tap to add image'),
                        ],
                      )
                    : ClipRRect(
                        borderRadius: BorderRadius.circular(20),

                        child: Image.file(selectedImage!, fit: BoxFit.cover),
                      ),
              ),
            ),

            const SizedBox(height: 25),

            // clothing name
            TextField(
              controller: nameController,

              decoration: InputDecoration(
                labelText: 'Clothing Name',

                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // category
            TextField(
              controller: categoryController,

              decoration: InputDecoration(
                labelText: 'Category',

                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),

            const SizedBox(height: 25),

            // mood title
            const Text(
              'Mood',

              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),

            const SizedBox(height: 10),

            // mood chips
            Wrap(
              spacing: 10,
              runSpacing: 10,

              children: moods.map((mood) {
                final isSelected = selectedMood == mood;

                return GestureDetector(
                  onTap: () {
                    setState(() {
                      selectedMood = mood;
                    });
                  },

                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),

                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),

                    decoration: BoxDecoration(
                      color: isSelected
                          ? Colors.deepPurple
                          : Colors.grey.shade200,

                      borderRadius: BorderRadius.circular(30),
                    ),

                    child: Text(
                      mood,

                      style: TextStyle(
                        color: isSelected ? Colors.white : Colors.black87,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 35),

            // save button
            SizedBox(
              width: double.infinity,

              child: ElevatedButton(
                onPressed: saveItem,

                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 18),

                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),

                child: const Text('Save Item', style: TextStyle(fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
