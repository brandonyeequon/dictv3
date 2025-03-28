import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:sqlite3_flutter_libs/sqlite3_flutter_libs.dart';
import 'dart:developer' as developer;

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;
  
  // Database file name
  static const String DB_NAME = 'V6.db';
  
  // Singleton constructor
  DatabaseHelper._init();
  
  Future<void> ensureInitialized() async {
    // Initialize sqlite3_flutter_libs
    try {
      await applyWorkaroundToOpenSqlite3OnOldAndroidVersions();
      // print SQLite version to verify everything is working
      var version = sqlite3.version;
      developer.log('SQLite version: $version');
    } catch (e) {
      developer.log('Error initializing sqlite3_flutter_libs: $e', error: e);
    }
    
    // Make sure database is opened
    await database;
  }

  Future<Database> get database async {
    if (_database != null) return _database!;
    
    _database = await _openDatabase();
    return _database!;
  }

  Future<Database> _openDatabase() async {
    // Get the directory for storing the database
    final Directory documentsDirectory = await getApplicationDocumentsDirectory();
    final String dbPath = join(documentsDirectory.path, DB_NAME);
    
    // Check if database already exists in documents directory
    final File dbFile = File(dbPath);
    if (!await dbFile.exists()) {
      // If not, copy from assets
      await _copyFromAssets(dbPath);
    }

    try {
      // Open the database
      developer.log('Opening database at: $dbPath');
      final db = sqlite3.open(dbPath);
      
      // Verify that FTS table exists
      try {
        final ftsTableExists = db.select(
          "SELECT name FROM sqlite_master WHERE type='table' AND name='dict_fts'"
        ).isNotEmpty;
        
        developer.log('FTS table exists: $ftsTableExists');
        
        if (ftsTableExists) {
          final tableInfo = db.select("PRAGMA table_info('dict_index')");
          developer.log('dict_index table columns: ${tableInfo.map((row) => row[1]).toList()}');
        }
      } catch (e) {
        developer.log('Error checking FTS table: $e', error: e);
      }
      
      return db;
    } catch (e) {
      developer.log('Error opening database: $e', error: e);
      rethrow;
    }
  }
  
  Future<void> _copyFromAssets(String dbPath) async {
    developer.log('Copying database from assets to $dbPath');
    try {
      // Read the database file from assets
      ByteData data = await rootBundle.load('assets/$DB_NAME');
      
      // Write to the documents directory
      List<int> bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
      await File(dbPath).writeAsBytes(bytes, flush: true);
      
      developer.log('Database copied successfully');
    } catch (e) {
      developer.log('Error copying database from assets: $e', error: e);
      rethrow;
    }
  }

  // Simple FTS search function
  Future<List<Map<String, dynamic>>> searchWords(String query) async {
    final db = await database;
    
    if (query.isEmpty) {
      return getAllWords();
    }
    
    try {
      // Format the query for FTS5
      final formattedQuery = query.split(' ').map((term) => '$term*').join(' ');
      
      // Log first few results' meaning field for debugging format
      try {
        final debugResult = db.select('''
          SELECT meaning FROM dict_fts WHERE dict_fts MATCH ? LIMIT 5
        ''', [formattedQuery]);
        
        for (final row in debugResult) {
          final meaning = row[0] as String;
          developer.log('DEBUG meaning format: "$meaning"');
        }
      } catch (e) {
        developer.log('Error during meaning format debug: $e', error: e);
      }
      
      // Execute the FTS query with the correct table names
      // We'll do a simple exact match against the first definition (everything before first semicolon)
      final ResultSet result = db.select('''
        SELECT 
            rowid,
            kanji,
            reading,
            meaning,
            romaji,
            pri_point,
            (
                pri_point + 
                CASE 
                    WHEN substr(meaning, 1, CASE WHEN instr(meaning, ';') > 0 THEN instr(meaning, ';') - 1 ELSE length(meaning) END) = ?
                    THEN 5000  -- Bonus points for exact first definition match
                    ELSE 0     -- No bonus for other matches
                END
            ) AS adjusted_pri_point,
            substr(meaning, 1, CASE WHEN instr(meaning, ';') > 0 THEN instr(meaning, ';') - 1 ELSE length(meaning) END) AS first_def
        FROM dict_fts
        WHERE dict_fts MATCH ?
        ORDER BY adjusted_pri_point DESC
        LIMIT 50
      ''', [query, formattedQuery]);
      
      // Convert ResultSet to List<Map<String, dynamic>>
      return _resultSetToList(result);
    } catch (e) {
      developer.log('Error during FTS search: $e', error: e);
      return [];
    }
  }

  // Get all words
  Future<List<Map<String, dynamic>>> getAllWords() async {
    final db = await database;
    
    try {
      final ResultSet result = db.select('''
        SELECT 
          *,
          pri_point AS adjusted_pri_point
        FROM dict_index 
        LIMIT 100
      ''');
      return _resultSetToList(result);
    } catch (e) {
      developer.log('Error getting all words: $e', error: e);
      return [];
    }
  }

  // Get table structure information
  Future<List<String>> getTableNames() async {
    final db = await database;
    
    try {
      final ResultSet result = db.select(
        "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'"
      );
      
      List<String> tableNames = [];
      for (final row in result) {
        tableNames.add(row[0] as String);
      }
      return tableNames;
    } catch (e) {
      developer.log('Error getting table names: $e', error: e);
      return [];
    }
  }
  
  // Get column information for a table
  Future<List<Map<String, dynamic>>> getTableColumns(String tableName) async {
    final db = await database;
    
    try {
      final ResultSet result = db.select("PRAGMA table_info($tableName)");
      return _resultSetToList(result);
    } catch (e) {
      developer.log('Error getting columns for table $tableName: $e', error: e);
      return [];
    }
  }
  
  // Helper method to convert ResultSet to List<Map<String, dynamic>>
  List<Map<String, dynamic>> _resultSetToList(ResultSet result) {
    List<Map<String, dynamic>> resultList = [];
    for (final row in result) {
      Map<String, dynamic> map = {};
      for (int i = 0; i < result.columnNames.length; i++) {
        final columnName = result.columnNames[i];
        map[columnName] = row[i];
      }
      resultList.add(map);
    }
    return resultList;
  }

  // Close the database (not often needed in mobile apps)
  void closeDatabase() {
    if (_database != null) {
      _database!.dispose();
      _database = null;
    }
  }
}