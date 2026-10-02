import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/item.dart';
import '../models/cart_model.dart';
import '../repositories/item_repository.dart';
import '../services/gemini_service.dart';
import 'checkout_page.dart';

class HomePage extends StatefulWidget {
  final ItemRepository repository;
  const HomePage({super.key, required this.repository});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late Future<List<Item>> _itemsFuture;

  @override
  void initState() {
    super.initState();
    _itemsFuture = widget.repository.getItems();
  }

  String _sanitizeText(String input) {
    // 1. ตัด Emoji ออกทั้งหมด ป้องกัน CanvasKit บน Flutter Web โหลดฟอนต์ NotoColorEmoji (~24MB) จนค้าง
    final noEmoji = input.replaceAll(
      RegExp(
        r'(\u00a9|\u00ae|[\u2000-\u3300]|\ud83c[\ud000-\udfff]|\ud83d[\ud000-\udfff]|\ud83e[\ud000-\udfff])',
        unicode: true,
      ),
      '',
    );

    // 2. ตัด Markdown formatting (#, *, `, _) และยุบหลายบรรทัดเป็นบรรทัดเดียว
    final clean = noEmoji.replaceAll(RegExp(r'[#*`_>]'), '').trim();
    final singleLine = clean.replaceAll(RegExp(r'\s+'), ' ');

    // 3. จำกัดความยาวไม่เกิน 85 ตัวอักษร ป้องกัน SnackBar ล้นจอ (RenderFlex overflow)
    if (singleLine.length > 85) {
      return '${singleLine.substring(0, 82)}...';
    }
    return singleLine.isNotEmpty ? singleLine : 'สวัสดีครับ ยินดีต้อนรับสู่ร้านค้า';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Campus Marketplace'),
        actions: [
          IconButton(
            icon: Badge(
              label: Text('${context.watch<CartModel>().itemCount}'),
              child: const Icon(Icons.shopping_cart),
            ),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CheckoutPage()),
            ),
          ),
        ],
      ),
      // ปุ่มทดสอบ Gemini ชั่วคราว (ขั้นตอนที่ 2.3) พร้อมแก้ปัญหา SnackBar บน Flutter Web
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.auto_awesome),
        label: const Text('ทดสอบ Gemini'),
        onPressed: () async {
          try {
            final rawText = await GeminiService().generateText(
              'ช่วยแต่งประโยคทักทายลูกค้าร้านค้าออนไลน์แบบเป็นกันเอง 1 ประโยคสั้นๆ ห้ามใส่ emoji หรือสัญลักษณ์พิเศษ',
            );
            print('Gemini: $rawText');

            // ตัด Emoji, Markdown และจำกัดความยาวเพื่อแสดงบน SnackBar ได้ทันที
            final displayText = _sanitizeText(rawText);

            await Future.delayed(const Duration(milliseconds: 100));
            if (!mounted || !context.mounted) return;

            ScaffoldMessenger.of(context).clearSnackBars();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                behavior: SnackBarBehavior.floating,
                content: Text(
                  displayText,
                  style: const TextStyle(fontSize: 14),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                duration: const Duration(seconds: 8),
              ),
            );
          } catch (e) {
            print('Gemini error: $e');
            final errorText = _sanitizeText(e.toString());

            await Future.delayed(const Duration(milliseconds: 100));
            if (!mounted || !context.mounted) return;

            ScaffoldMessenger.of(context).clearSnackBars();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                behavior: SnackBarBehavior.floating,
                content: Text(
                  errorText,
                  style: const TextStyle(fontSize: 14),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                duration: const Duration(seconds: 8),
              ),
            );
          }
        },
      ),
      body: FutureBuilder<List<Item>>(
        future: _itemsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('เกิดข้อผิดพลาด: ${snapshot.error}'));
          }
          final items = snapshot.data ?? [];
          if (items.isEmpty) {
            return const Center(child: Text('ไม่พบสินค้า'));
          }
          return ListView.builder(
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              return ListTile(
                leading: Image.network(
                  item.imageUrl,
                  width: 48,
                  height: 48,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) =>
                      const Icon(Icons.broken_image),
                ),
                title: Text(item.title),
                subtitle: Text('${item.price} บาท'),
                trailing: IconButton(
                  icon: const Icon(Icons.add_shopping_cart),
                  onPressed: () async {
                    context.read<CartModel>().add(item);
                    await Future.delayed(const Duration(milliseconds: 100));
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).clearSnackBars();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('เพิ่ม "${item.title}" ลงตะกร้าแล้ว')),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
