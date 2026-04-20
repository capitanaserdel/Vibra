import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:music/core/services/file_management_service.dart';
import 'package:music/core/services/metadata_service.dart';

final fileManagementServiceProvider = Provider((ref) => FileManagementService());
final metadataServiceProvider = Provider((ref) => MetadataService());
