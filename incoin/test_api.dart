import 'dart:io';
import 'package:http/http.dart' as http;
void main() async {
  var headers = {'timestamp': '123', 'version': '46', 'OSVersion': '30', 'clientType': 'Android', 'appId': 'xyz.indianx.app'};
  var response = await http.get(Uri.parse('https://api.incoinpay.net/anon/client/checkVersion'), headers: headers);
  File('api.json').writeAsStringSync(response.body);
}
