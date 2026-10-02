# campus_marketplace_w7

MDSD Lab 7: Google AI Studio & Gemini API Integration

แอป Campus Marketplace ที่ต่อยอดจากใบงานสัปดาห์ที่ 5-6 เพิ่มหน้าลงประกาศขายสินค้าที่ให้ Gemini Vision ช่วยร่างชื่อประกาศ หมวดหมู่ และคำบรรยายจากรูปสินค้า แล้วให้ผู้ใช้ตรวจทานแก้ไขก่อนยืนยัน

## โครงสร้างหลัก

- `lib/services/gemini_service.dart` เรียก Gemini แบบข้อความ
- `lib/services/gemini_vision_service.dart` ส่งรูปภาพแบบ Base64 พร้อม Prompt และใช้ `responseSchema` บังคับให้ได้ JSON
- `lib/models/listing_draft.dart` โมเดลร่างประกาศ
- `lib/screens/sell_item_page.dart` หน้าลงประกาศขาย เลือกรูป วิเคราะห์ด้วย AI ตรวจทานและยืนยัน
- `lib/screens/main_scaffold.dart` Bottom Navigation Bar ด้วย `IndexedStack`

## การรัน

```bash
flutter pub get
flutter run -d chrome --dart-define=GEMINI_API_KEY=YOUR_API_KEY
```

ห้าม commit API Key ให้ส่งผ่าน `--dart-define` เท่านั้น

ใบงานและผลการทดลอง: https://github.com/Kritternai/MDSD-Lab7-Labsheet-2026
