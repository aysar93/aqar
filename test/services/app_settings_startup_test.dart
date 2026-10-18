import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aqar/providers/app_settings_provider.dart';
class SettingsSnapshot extends Fake implements DocumentSnapshot<Map<String,dynamic>> {
 final Map<String,dynamic>? value;
 SettingsSnapshot(this.value);
 @override bool get exists=>value!=null;
 @override Map<String,dynamic>? data()=>value;
}
class SettingsDocument extends Fake implements DocumentReference<Map<String,dynamic>> {
 final Map<String,dynamic>? value; final String? error;
 SettingsDocument(this.value,this.error);
 @override Future<DocumentSnapshot<Map<String,dynamic>>> get([GetOptions? options]) async {
  if(error!=null) throw FirebaseException(plugin:'cloud_firestore',code:error!);
  return SettingsSnapshot(value);
 }
}
class SettingsCollection extends Fake implements CollectionReference<Map<String,dynamic>> {
 final SettingsDocument reference; SettingsCollection(this.reference);
 @override DocumentReference<Map<String,dynamic>> doc([String? path]) {expect(path,'app_settings');return reference;}
}
class SettingsDB extends Fake implements FirebaseFirestore {
 final SettingsDocument reference; SettingsDB({Map<String,dynamic>? value,String? error}):reference=SettingsDocument(value,error);
 @override CollectionReference<Map<String,dynamic>> collection(String path) {expect(path,'settings');return SettingsCollection(reference);}
}
void main() {
 for(final code in ['permission-denied','unavailable']) {
  test('optional branding preserves startup defaults after $code',() async {
   final p=AppSettingsProvider(firestore:SettingsDB(error:code));final before=[p.appName,p.officeName,p.logoUrl];
   await expectLater(p.loadSettings(),completes);expect([p.appName,p.officeName,p.logoUrl],before);p.dispose();
  });
 }
 test('valid branding still loads and notifies once',() async {
  final p=AppSettingsProvider(firestore:SettingsDB(value:{'appName':'Synthetic app','officeName':'Synthetic office','logoUrl':'https://example.test/logo.png'}));var n=0;p.addListener(()=>n++);
  await p.loadSettings();expect(p.appName,'Synthetic app');expect(p.officeName,'Synthetic office');expect(p.logoUrl,'https://example.test/logo.png');expect(n,1);p.dispose();
 });
 test('malformed optional fields cannot corrupt typed defaults',() async {
  final p=AppSettingsProvider(firestore:SettingsDB(value:{'appName':123,'officeName':false,'logoUrl':[]}));final before=[p.appName,p.officeName,p.logoUrl];
  await expectLater(p.loadSettings(),completes);expect([p.appName,p.officeName,p.logoUrl],before);p.dispose();
 });
}
