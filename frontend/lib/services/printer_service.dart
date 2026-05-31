import 'package:blue_thermal_printer/blue_thermal_printer.dart';

class PrinterService {
  final BlueThermalPrinter bluetooth = BlueThermalPrinter.instance;

  Future<List<BluetoothDevice>> getDevices() async {
    try {
      return await bluetooth.getBondedDevices();
    } catch (e) {
      return [];
    }
  }

  Future<void> printReceipt(Map<String, dynamic> transaction) async {
    bool? isConnected = await bluetooth.isConnected;
    if (isConnected == null || !isConnected) return;

    // ESC/POS Commands
    bluetooth.write("      EARTH PETSHOP      \n");
    bluetooth.write("--------------------------------\n");
    bluetooth.write("Invoice: ${transaction['invoice_number']}\n");
    bluetooth.write("Date: ${DateTime.now().toString().substring(0,16)}\n");
    bluetooth.write("--------------------------------\n");
    
    final items = transaction['items'] as List;
    for (var item in items) {
      bluetooth.write("${item['product_name']}\n");
      bluetooth.write("${item['qty']} x ${item['price']}    IDR ${item['qty'] * item['price']}\n");
    }
    
    bluetooth.write("--------------------------------\n");
    bluetooth.write("TOTAL: IDR ${transaction['total']}\n");
    bluetooth.write("--------------------------------\n");
    bluetooth.write("   Thank you for shopping!   \n\n\n");
    
    bluetooth.paperCut();
  }

  Future<bool> connect(BluetoothDevice device) async {
    try {
      await bluetooth.connect(device);
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<void> disconnect() async {
    await bluetooth.disconnect();
  }
}
