// This file maintains backward compatibility.
// The actual page implementations have been moved to dedicated page files.

export 'pages/home_page.dart' show HomePage;
export 'pages/folder_page.dart' show FolderPage;

// For backward compatibility with the old FrontPage name
import 'pages/home_page.dart';

typedef FrontPage = HomePage;