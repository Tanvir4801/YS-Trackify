import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/temp_labour_entry.dart';

class TempLabourService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Fetches all temporary labour entries for a specific date and contractor.
  Future<List<TempLabourEntry>> fetchEntriesForDate(String contractorId, String date) async {
    try {
      final snap = await _db
          .collection('temp_labour_entries')
          .where('contractorId', isEqualTo: contractorId)
          .where('date', isEqualTo: date)
          .get();
      return snap.docs.map((doc) => TempLabourEntry.fromFirestore(doc)).toList();
    } catch (e) {
      debugPrint('Error fetching temp labours for date $date: $e');
      return [];
    }
  }

  /// Adds a new temporary labour entry for today's work.
  Future<TempLabourEntry> addEntry(TempLabourEntry entry) async {
    try {
      await _db.collection('temp_labour_entries').doc(entry.id).set(entry.toFirestore());
      return entry;
    } catch (e) {
      debugPrint('Error adding temp labour entry: $e');
      rethrow;
    }
  }

  /// Updates an existing temporary labour entry.
  Future<void> updateEntry(TempLabourEntry entry) async {
    try {
      await _db.collection('temp_labour_entries').doc(entry.id).update(entry.toFirestore());
    } catch (e) {
      debugPrint('Error updating temp labour entry: $e');
      rethrow;
    }
  }

  /// Deletes a temporary labour entry.
  Future<void> deleteEntry(String entryId) async {
    try {
      await _db.collection('temp_labour_entries').doc(entryId).delete();
    } catch (e) {
      debugPrint('Error deleting temp labour entry: $e');
      rethrow;
    }
  }

  /// Searches historical temporary labours for the auto-fill feature.
  /// Finds entries for this contractor matching the name prefix.
  Future<List<TempLabourEntry>> searchHistoricalEntries(String contractorId, String query) async {
    if (query.trim().isEmpty) return [];
    try {
      // Basic prefix search
      final snap = await _db
          .collection('temp_labour_entries')
          .where('contractorId', isEqualTo: contractorId)
          .where('name', isGreaterThanOrEqualTo: query)
          .where('name', isLessThanOrEqualTo: '$query\uf8ff')
          .limit(10)
          .get();
      
      // We may get multiple entries for the same person on different days.
      // We want to return unique historical profiles.
      final uniqueProfiles = <String, TempLabourEntry>{};
      for (final doc in snap.docs) {
        final entry = TempLabourEntry.fromFirestore(doc);
        // Prioritize more recent entries if they share the exact name
        final existing = uniqueProfiles[entry.name];
        if (existing == null || entry.createdAt.isAfter(existing.createdAt)) {
          uniqueProfiles[entry.name] = entry;
        }
      }
      return uniqueProfiles.values.toList();
    } catch (e) {
      debugPrint('Error searching historical temp labours: $e');
      return [];
    }
  }
}
