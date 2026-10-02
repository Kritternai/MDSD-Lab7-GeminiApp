import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/listing_draft.dart';
import '../services/gemini_vision_service.dart';

class SellItemPage extends StatefulWidget {
  const SellItemPage({super.key});

  @override
  State<SellItemPage> createState() => _SellItemPageState();
}

class _SellItemPageState extends State<SellItemPage> {
  static const _prompt = '''คุณคือผู้ช่วยเขียนประกาศขายของมือสองในตลาดนัดออนไลน์สำหรับนักศึกษามหาวิทยาลัย
จากรูปภาพสินค้าที่แนบมา ให้วิเคราะห์แล้วตอบกลับเป็น JSON เท่านั้น ตามโครงสร้างนี้:
{
  "title": "ชื่อประกาศสั้นกระชับ ไม่เกิน 40 ตัวอักษร",
  "category": "หมวดหมู่ที่เหมาะสมที่สุด เลือกจาก: หนังสือเรียน, อุปกรณ์อิเล็กทรอนิกส์, ของแต่งหอพัก, เสื้อผ้า, อื่นๆ",
  "description": "คำบรรยายสินค้า 2-3 ประโยค ที่ดึงดูดผู้ซื้อและบอกสภาพของสินค้าตามที่เห็นในภาพ"
}
ห้ามตอบข้อความอื่นนอกเหนือจาก JSON ดังกล่าว''';

  XFile? _selectedImage;
  Uint8List? _imageBytes;

  bool _isAnalyzing = false;
  String? _errorMessage;
  ListingDraft? _draft;

  final _titleController = TextEditingController();
  final _categoryController = TextEditingController();
  final _descriptionController = TextEditingController();

  // ร่างประกาศที่ผู้ใช้ยืนยันแล้ว เก็บไว้ใน State ก่อน (บันทึกถาวรในสัปดาห์ที่ 8)
  final List<ListingDraft> _confirmedDrafts = [];

  @override
  void dispose() {
    _titleController.dispose();
    _categoryController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked == null) return;

    final bytes = await picked.readAsBytes();
    setState(() {
      _selectedImage = picked;
      _imageBytes = bytes;
      _draft = null;
      _errorMessage = null;
    });
  }

  Future<void> _analyzeImage() async {
    if (_selectedImage == null || _imageBytes == null) return;

    setState(() {
      _isAnalyzing = true;
      _errorMessage = null;
      _draft = null;
    });

    try {
      final draft = await GeminiVisionService().analyzeProductImage(
        imageBytes: _imageBytes!,
        mimeType: _selectedImage!.mimeType ?? 'image/jpeg',
        prompt: _prompt,
      );
      setState(() {
        _draft = draft;
        _titleController.text = draft.title;
        _categoryController.text = draft.category;
        _descriptionController.text = draft.description;
      });
    } catch (e) {
      setState(() => _errorMessage = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      setState(() => _isAnalyzing = false);
    }
  }

  Widget _buildResult() {
    if (_isAnalyzing) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 12),
            Text('AI กำลังวิเคราะห์ภาพสินค้า...'),
          ],
        ),
      );
    }
    if (_errorMessage != null) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
      );
    }
    if (_draft == null) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('ตรวจทานและแก้ไขร่างประกาศจาก AI ก่อนยืนยัน'),
        const SizedBox(height: 12),
        TextField(
          controller: _titleController,
          decoration: const InputDecoration(
            labelText: 'ชื่อประกาศ',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _categoryController,
          decoration: const InputDecoration(
            labelText: 'หมวดหมู่',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _descriptionController,
          maxLines: 4,
          decoration: const InputDecoration(
            labelText: 'คำบรรยาย',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: _confirmDraft,
          icon: const Icon(Icons.check),
          label: const Text('ยืนยันร่างประกาศ'),
        ),
      ],
    );
  }

  Future<void> _confirmDraft() async {
    final finalDraft = ListingDraft(
      title: _titleController.text.trim(),
      category: _categoryController.text.trim(),
      description: _descriptionController.text.trim(),
    );

    setState(() {
      _confirmedDrafts.add(finalDraft);
      _selectedImage = null;
      _imageBytes = null;
      _draft = null;
      _errorMessage = null;
      _titleController.clear();
      _categoryController.clear();
      _descriptionController.clear();
    });

    // รอ 100ms ให้ Flutter Web render frame ให้พร้อมก่อนแสดง SnackBar
    await Future.delayed(const Duration(milliseconds: 100));
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('บันทึกร่างประกาศเรียบร้อยแล้ว')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ลงประกาศขายสินค้า')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              height: 240,
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(12),
              ),
              clipBehavior: Clip.antiAlias,
              child: _imageBytes != null
                  ? Image.memory(_imageBytes!, fit: BoxFit.cover)
                  : const Icon(Icons.image, size: 80, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _pickImage,
              icon: const Icon(Icons.photo_library),
              label: const Text('เลือกรูปภาพสินค้า'),
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: _selectedImage == null || _isAnalyzing ? null : _analyzeImage,
              icon: const Icon(Icons.auto_awesome),
              label: const Text('ให้ AI ช่วยแนะนำ'),
            ),
            const SizedBox(height: 16),
            _buildResult(),
          ],
        ),
      ),
    );
  }
}
