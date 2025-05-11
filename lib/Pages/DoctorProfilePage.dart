import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class DoctorProfilePage extends StatefulWidget {
  @override
  _DoctorProfilePageState createState() => _DoctorProfilePageState();
}

class _DoctorProfilePageState extends State<DoctorProfilePage> {
  TextEditingController _nameController = TextEditingController();
  TextEditingController _specializationController = TextEditingController();
  String _email = '';
  String _profileImageUrl = '';
  File? _imageFile;
  bool _isLoading = true;
  bool _isEditing = false; // Toggle between view and edit mode
  List<String> _specializations = [];

  @override
  void initState() {//this is called where create a widge first
    super.initState();
    _fetchDoctorProfile();
  }

  // Fetch doctor profile from Firestore
  Future<void> _fetchDoctorProfile() async {
    try {
      User? currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {//Ensures that a user is logged in before proceeding.
        DocumentSnapshot doctorDoc = await FirebaseFirestore.instance
            .collection('doctors')
            .doc(currentUser.uid)
            .get();

        if (doctorDoc.exists) {//check if the document exist in firestore.
          setState(() {
            _nameController.text = doctorDoc['name'] ?? '';
            _email = doctorDoc['email'] ?? currentUser.email!;
            _profileImageUrl = doctorDoc['imageUrl'] ?? '';
            _specializations = List<String>.from(doctorDoc['specializations'] ?? []);
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      print('Error fetching doctor profile: $e');
    }
  }

  //This function uploads a profile picture to Firebase Storage.
  Future<String?> _uploadProfilePicture(File imageFile) async {
    try {
      User? currentUser = FirebaseAuth.instance.currentUser;//fetch current user
      if (currentUser != null) {
        String filePath = 'profile_images/${currentUser.uid}.jpg';
        UploadTask uploadTask = FirebaseStorage.instance.ref(filePath).putFile(imageFile);
        TaskSnapshot snapshot = await uploadTask;
        String downloadUrl = await snapshot.ref.getDownloadURL();
        return downloadUrl;
      }
    } catch (e) {
      print('Error uploading profile picture: $e');
    }
    return null;
  }

  // Update the doctor's profile in Firestore
  Future<void> _updateDoctorProfile() async {
    try {
      User? currentUser = FirebaseAuth.instance.currentUser;//Fetches the current user.

      if (currentUser != null) {
        if (_imageFile != null) {//Checks if a new profile picture has been selected.
          String? newImageUrl = await _uploadProfilePicture(_imageFile!);
          if (newImageUrl != null) {
            _profileImageUrl = newImageUrl;
          }
        }
        await FirebaseFirestore.instance.collection('users').doc(
            currentUser.uid).update({
          'name': _nameController.text,
          'profileImageUrl': _profileImageUrl,
        });
        await FirebaseFirestore.instance.collection('doctors').doc(
            currentUser.uid).update({
          'name': _nameController.text,
          'imageUrl': _profileImageUrl,
          'specializations': _specializations,
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Profile updated successfully!')),
        );
      }
    }
    catch (e) {
      print('Error updating profile: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating profile.')),
      );
    }
  }

  // Pick an image from the gallery
  Future<void> _pickImage() async {
    //open image gallery
    final pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {//This checks if an image was actually picked
      setState(() {
        _imageFile = File(pickedFile.path);
      });
      // You can upload the image to Firebase Storage and update the profileImageUrl here
    }
  }

  // Add Specialization dialog
  Future<void> _addSpecializationDialog() async {//and it’s used to display a dialog box to input a new specialization.
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return AlertDialog(//the dialog itself is an AlertDialog, which is a pop-up window containing a title, content, and actions.
          title: Text('Add Specialization'),
          content: TextField(
            controller: _specializationController,
            decoration: InputDecoration(
              labelText: 'Enter Specialization',
              hintText: 'E.g., Cardiologist, Dermatologist',
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text('Add'),
              onPressed: () {
                setState(() {
                  if (_specializationController.text.isNotEmpty) {
                    _specializations.add(_specializationController.text);
                    _specializationController.clear();
                  }
                });
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  //  It takes in one parameter index, which is the index of the specialization to remove from the list.
  void _removeSpecialization(int index) {
    setState(() {
      _specializations.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Doctor Profile'),
        backgroundColor: Colors.teal[300],
        actions: [
          IconButton(
            icon: Icon(_isEditing ? Icons.save : Icons.edit), // Toggle between edit and save icon
            onPressed: () {
              if (_isEditing) {
                // Save the profile when save icon is clicked
                _updateDoctorProfile();
              }
              setState(() {
                _isEditing = !_isEditing; // Toggle between edit and view mode
              });
            },
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            children: <Widget>[
              // Profile Image
              CircleAvatar(
                radius: 60,
                backgroundImage:
                _imageFile != null ? FileImage(_imageFile!) : NetworkImage(_profileImageUrl) as ImageProvider,
              ),
              if (_isEditing)
                TextButton.icon(
                  icon: Icon(Icons.camera_alt),
                  label: Text('Change Profile Picture'),
                  onPressed: _pickImage, // Pick an image only in edit mode
                ),
              SizedBox(height: 16.0),

              // Name field (editable only in edit mode)
              TextField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Name',
                  border: OutlineInputBorder(),
                ),
                readOnly: !_isEditing, // Make it non-editable in view mode
              ),
              SizedBox(height: 16.0),

              // Email field (read-only)
              TextField(
                controller: TextEditingController(text: _email),
                decoration: InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                ),
                readOnly: true, // Email is always read-only
              ),
              SizedBox(height: 16.0),

              // Specializations (editable only in edit mode)
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Specializations:',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                  if (_isEditing)
                    IconButton(
                      icon: Icon(Icons.add),
                      onPressed: _addSpecializationDialog, // Add specialization in edit mode
                    ),
                ],
              ),
              SizedBox(height: 8.0),

              // Display list of specializations
              ListView.builder(
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                itemCount: _specializations.length,
                itemBuilder: (context, index) {
                  return ListTile(
                    title: Text(_specializations[index]),
                    trailing: _isEditing
                        ? IconButton(
                      icon: Icon(Icons.delete),
                      onPressed: () => _removeSpecialization(index), // Remove specialization in edit mode
                    )
                        : null,
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
