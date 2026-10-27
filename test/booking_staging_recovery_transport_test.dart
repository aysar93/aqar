import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import '../tool/booking_network/staging_screen_adapter.dart';
void main(){test('original recovery HEAD then GET use fresh clients; upload fence unused',()async{
 final server=await HttpServer.bind(InternetAddress.loopbackIPv4,0);
 final received=<String>[];final payload=[1,2,3,4];
 final sub=server.listen((r)async{received.add(r.method);r.response.contentLength=payload.length;if(r.method!='HEAD')r.response.add(payload);await r.response.close();});
 final upload=SingleAttemptStagingClient();
 try{
  final url=Uri.parse('http://127.0.0.1:${server.port}/synthetic');
  await http.runWithClient(()async{
   final head=await http.head(url);expect(head.statusCode,200);expect(head.headers['content-length'],'4');
   final get=await http.get(url);expect(get.bodyBytes,payload);
  },()=>stagingClientForPhase(recovery:true,upload:upload));
  expect(received,['HEAD','GET']);expect(upload.sent,isFalse);expect(upload.events,isEmpty);
 }finally{upload.close();await sub.cancel();await server.close(force:true);}
});}
