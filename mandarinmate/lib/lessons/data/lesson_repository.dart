import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mandarinmate/features/lessons/domain/lesson_model.dart';

class LessonRepository {
  final FirebaseFirestore _firestore;

  LessonRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  Stream<List<LessonUnit>> get lessonUnits {
    return _firestore.collection('lessons').orderBy('order').snapshots().map((
      snapshot,
    ) {
      return snapshot.docs
          .map((doc) => LessonUnit.fromFirestore(doc.data(), doc.id))
          .toList();
    });
  }

  Future<List<VocabItem>> getVocabForUnit(String unitDocId) async {
    final snapshot = await _firestore
        .collection('lessons')
        .doc(unitDocId)
        .collection('vocab')
        .get();

    return snapshot.docs.map((doc) => VocabItem.fromMap(doc.data())).toList();
  }
}
