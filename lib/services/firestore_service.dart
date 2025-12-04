// lib/services/firestore_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/student_model.dart';
import '../models/app_settings_model.dart';

enum StudentArchiveStatusFilter { active, archived, all }

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final String _studentsCollection = 'students';
  final String _settingsCollection = 'settings';

  Stream<AppSettings> getAppSettingsStream() {
    return _db
        .collection(_settingsCollection)
        .doc(appSettingsDocId)
        .snapshots()
        .map((snapshot) {
      if (snapshot.exists) {
        return AppSettings.fromSnapshot(snapshot);
      }
      return AppSettings(feeHistory: [
        FeeHistoryEntry(effectiveDate: DateTime(2020, 1, 1), fee: 2000.0)
      ]);
    });
  }

  Future<void> addNewFee(double newFee, DateTime effectiveDate) {
    final newFeeEntry = FeeHistoryEntry(effectiveDate: effectiveDate, fee: newFee);
    final docRef = _db.collection(_settingsCollection).doc(appSettingsDocId);

    return docRef.set({
      'feeHistory': FieldValue.arrayUnion([newFeeEntry.toMap()])
    }, SetOptions(merge: true));
  }

  Stream<List<Student>> getStudentsStream({
    String? nameSearchTerm,
    StudentArchiveStatusFilter archiveStatusFilter = StudentArchiveStatusFilter.active,
  }) {
    Query query = _db.collection(_studentsCollection);

    if (archiveStatusFilter == StudentArchiveStatusFilter.active) {
      query = query.where('isArchived', isEqualTo: false);
    } else if (archiveStatusFilter == StudentArchiveStatusFilter.archived) {
      query = query.where('isArchived', isEqualTo: true);
    }

    if (nameSearchTerm != null && nameSearchTerm.isNotEmpty) {
      String lowerSearchTerm = nameSearchTerm.toLowerCase();
      query = query
          .where('name_lowercase', isGreaterThanOrEqualTo: lowerSearchTerm)
          .where('name_lowercase', isLessThanOrEqualTo: lowerSearchTerm + '\uf8ff');
      query = query.orderBy('name_lowercase');
    } else {
      query = query.orderBy('name');
    }


    return query.snapshots().map((snapshot) {
      try {
        return snapshot.docs.map((doc) => Student.fromSnapshot(doc)).toList();
      } catch (e) {
        print("Error mapping students in FirestoreService: $e");
        return [];
      }
    });
  }

  Stream<Student?> getStudentStream(String studentId) {
    return _db.collection(_studentsCollection).doc(studentId).snapshots().map((snapshot) {
      if (snapshot.exists) {
        try {
          return Student.fromSnapshot(snapshot);
        } catch (e) {
          print("Error mapping student $studentId in FirestoreService: $e");
          return null;
        }
      }
      return null;
    });
  }

  Future<bool> studentExists(String studentId) async {
    final doc = await _db.collection(_studentsCollection).doc(studentId).get();
    return doc.exists;
  }

  Future<void> addStudent(Student student) {
    return _db.collection(_studentsCollection).doc(student.id).set(student.toMap());
  }

  Future<void> updateStudent(String studentId, Student student) {
    Map<String, dynamic> studentData = student.toMap();
    return _db.collection(_studentsCollection).doc(studentId).update(studentData);
  }

  Future<void> updateStudentPartial(String studentId, Map<String, dynamic> data) {
    if (data.containsKey('name') && data['name'] is String) {
      data['name_lowercase'] = (data['name'] as String).toLowerCase();
    }
    if (data.containsKey('messStartDate') && data['messStartDate'] is DateTime) {
      data['messStartDate'] = Timestamp.fromDate(data['messStartDate'] as DateTime);
    }
    if (data.containsKey('attendanceLog') && data['attendanceLog'] is List) {
      data['attendanceLog'] = (data['attendanceLog'] as List<dynamic>).map((e) {
        if (e is AttendanceEntry) return e.toMap();
        if (e is Map<String,dynamic>) return e;
        return {};
      }).toList();
    }
    if (data.containsKey('paymentHistory') && data['paymentHistory'] is List) {
      data['paymentHistory'] = (data['paymentHistory'] as List<dynamic>).map((e) {
        if (e is PaymentHistoryEntry) return e.toMap();
        if (e is Map<String,dynamic>) return e;
        return {};
      }).toList();
    }
    return _db.collection(_studentsCollection).doc(studentId).update(data);
  }

  Future<void> setStudentArchiveStatus(String studentId, bool isArchived) {
    return _db.collection(_studentsCollection).doc(studentId).update({
      'isArchived': isArchived,
    });
  }

  Future<void> deleteStudent(String studentId) {
    return _db.collection(_studentsCollection).doc(studentId).delete();
  }

  Future<void> addAttendanceEntry(String studentId, AttendanceEntry entry) {
    return _db.collection(_studentsCollection).doc(studentId).update({
      'attendanceLog': FieldValue.arrayUnion([entry.toMap()])
    });
  }
}