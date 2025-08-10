import '../services/search_service.dart';

// Export the SearchService from the wrapper for easy importing
export '../services/search_service.dart' show SearchService;

// Additional wrapper functions can be added here if needed
class SearchServiceWrapper {
  static final SearchService _searchService = SearchService();
  
  static SearchService get instance => _searchService;
}
