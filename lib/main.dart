import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:ui';
import 'dart:io';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:isbn_book_search_test_flutter/utils.dart';
import 'package:isbn_book_search_test_flutter/result_text_view.dart';
import 'package:xml2json/xml2json.dart';
import 'package:url_launcher/url_launcher.dart';


void main() => runApp(MaterialApp(home: Home()));

class Home extends StatelessWidget {
  final isbnController = TextEditingController();

  void search(BuildContext context, String isbn) {
    if (isbn.length == 10 || isbn.length == 13) {
      if (IsbnUtils.isValidIsbn(isbn)) {
        // Use the isValidIsbn method from IsbnUtils class
        // Navigate to the result page
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => SearchResult(isbn: isbn)),
        );
      } else {
        // Show an error message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            duration: Duration(milliseconds: 500),
            content: Text('Invalid ISBN'),
          ),
        );
      }
    } else {
      // Show an error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: Duration(milliseconds: 500),
          content:
              Text('Invalid ISBN length. Please enter a 10 or 13 digit ISBN.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
          child: Row(
        children: <Widget>[
          Expanded(
            flex: 1, // 20%
            child: Container(),
          ),
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                TextField(
                  controller: isbnController,
                  // add this controller
                  decoration: InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: 'Input ISBN Here',
                    floatingLabelAlignment: FloatingLabelAlignment.center,
                  ),
                  textAlign: TextAlign.center,
                  maxLength: 13,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  autocorrect: false,
                ),
                FilledButton(
                  onPressed: () {
                    String isbn = isbnController.text;
                    search(context,
                        isbn); // Pass the context parameter to the search method
                  },
                  child: const Text('Search'),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 1, // 20%
            child: Container(),
          )
        ],
      )),
      floatingActionButton: Platform.isAndroid || Platform.isIOS
          ? FloatingActionButton(
              onPressed: () {},
              child: IconButton(
                  icon: SvgPicture.asset('images/barcode_scanner.svg',
                      colorFilter:
                          ColorFilter.mode(Colors.white, BlendMode.srcIn)),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => ScanPage()),
                    );
                  }),
            )
          : null,
    );
  }
}

class ScanPage extends StatefulWidget {
  @override
  _ScanPageState createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage> {
  String? lastScan;
  String? thisScan;

  MobileScannerController controller = MobileScannerController(
    facing: CameraFacing.back,
    torchEnabled: false,
    detectionTimeoutMs: 1000,
    detectionSpeed: DetectionSpeed.noDuplicates,
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Row(
          children: <Widget>[
            Expanded(
              flex: 1,
              child: Container(),
            ),
            Expanded(
                flex: 4,
                child: Column(
                  children: [
                    Expanded(
                      flex: 4,
                      child: Text(""),
                    ),
                    Expanded(
                        flex: 3,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: MobileScanner(
                            fit: BoxFit.cover,
                            controller: controller,
                            onDetect: (capture) {
                              final List<Barcode> barcodes = capture.barcodes;
                              for (final barcode in barcodes) {
                                final String? isbn = barcode.rawValue;
                                if (isbn != null &&
                                    (isbn.length == 10 || isbn.length == 13) &&
                                    IsbnUtils.isValidIsbn(isbn)) {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (context) =>
                                            SearchResult(isbn: isbn)),
                                  );
                                  return;
                                }
                              }
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  duration: Duration(milliseconds: 500),
                                  content: Text('No valid ISBN found'),
                                ),
                              );
                            },
                          ),
                        )),
                    Expanded(
                        flex: 2,
                        child: Padding(
                            padding: EdgeInsets.fromLTRB(0, 15, 0, 0),
                            child: Text("Scan an ISBN barcode to learn more.",
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontWeight: FontWeight.w500,
                                  fontStyle: FontStyle.normal,
                                  //fontSize: 16,
                                  color: Color(0xff000000),
                                )))),
                    Expanded(
                      flex: 5,
                      child: Text(""),
                    ),
                  ],
                )),
            Expanded(
              flex: 1,
              child: Container(),
            )
          ],
        ),
      ),
      floatingActionButton: Platform.isAndroid || Platform.isIOS
          ? FloatingActionButton(
              onPressed: () {},
              child: IconButton(
                icon: Icon(Icons.keyboard),
                onPressed: () {
                  Navigator.pop(context);
                },
              ),
            )
          : null,
    );
  }
}

class SearchResult extends StatefulWidget {
  final String isbn;

  SearchResult({required this.isbn});

  @override
  _SearchResultState createState() => _SearchResultState();
}

class _SearchResultState extends State<SearchResult> {
  String _title = '';
  String _authors = '';
  String _isbn = '';
  String _publisher = '';
  String _publicationYear = '';
  String _description = '';
  String _coverlink = '';
  String _ddc = '';
  String _bookNew = '', _bookUsed = '', _destination = '';

  @override
  void initState() {
    super.initState();
    search(widget.isbn);
  }

  void search(String isbn) async {
    _isbn = isbn;

    // Make an HTTP GET request to the OCLC Classify API
    String url0 =
        "http://classify.oclc.org/classify2/Classify?isbn=$_isbn&summary=true";
    http.Response response0 = await http.get(Uri.parse(url0));
    //Check the response status code
    if (response0.statusCode == 200) {
      final transformer = Xml2Json();
      transformer.parse(response0.body);
      String json = transformer.toParkerWithAttrs();
      print(json);

      var title;
      var authors;
      var ddc;
      if (json != "") {
        if (jsonDecode(json)['classify']['response']['_code'] == '0' ||
            jsonDecode(json)['classify']['response']['_code'] == '4') {
          if (jsonDecode(json)['classify']['work'] != null) {
            authors = jsonDecode(json)['classify']['work']['_author'];
            title = jsonDecode(json)['classify']['work']['_title'];
          } else {
            authors =
                jsonDecode(json)['classify']['works']['work'][0]['_author'];
            title = jsonDecode(json)['classify']['works']['work'][0]['_title'];
          }
          if (jsonDecode(json)['classify']['recommendations'] != null)
            ddc = jsonDecode(json)['classify']['recommendations']['ddc']
                ['mostPopular']['_nsfa'];
        }
      }
      setState(() {
        if (title != null) _title = title;
        if (authors != null) _authors = authors;
        if (ddc != null) _ddc = ddc;
      });
      print('url0 queried');
    } else {
      print('url0 failed');
    }

    // Make an HTTP GET request to the Openlibrary
    String url1 = "https://openlibrary.org/isbn/$_isbn.json";
    // String url1 = "http://openlibrary.org/api/volumes/brief/isbn/$_isbn.json"

    http.Response response1 = await http.get(Uri.parse(url1));
    //Check the response status code
    print(response1.body);
    if (response1.statusCode == 200) {
      // Parse the response JSON
      var data = jsonDecode(response1.body);
      var title, authors, publisher, publicationYear, coverlink, coverid, ddc;
      if (data['title'] != null) title = data['title'];
      if (data['authors'][0]['name'] != null)
        authors = data['authors'][0]['name'];
      if (data['publisher'] != null) publisher = data['publisher'];
      if (data['publish_date'] != null) {
        publicationYear = data['publish_date'];
        //publicationYear = publicationYear.substring(publicationYear.length - 4);
      }
      if (data['covers'] != null) coverid = data['covers'][0];
      if (coverid != null)
        coverlink = "https://covers.openlibrary.org/b/id/$coverid-L.jpg";
      if (data['dewey_decimal_class'] != null){
        ddc = data['dewey_decimal_class'][0];
        ddc = ddc.replaceAll('/', '');
    }

      setState(() {
        if (title != null && _title == "") _title = title;
        if (authors != null && _authors == "") _authors = authors;
        if (publisher != null && _publisher == "") _publisher = publisher;
        if (publicationYear != null && _publicationYear == "")
          _publicationYear = publicationYear;
        if (coverlink != null && _coverlink == "") _coverlink = coverlink;
        if (ddc != null && _ddc == "") _ddc = ddc;
      });
      print('url1 queried');
    } else {
      print('url1 failed');
    }

    // Make an HTTP GET request to the Google Books API
    String url2 = "https://www.googleapis.com/books/v1/volumes?q=isbn:$_isbn";
    http.Response response2 = await http.get(Uri.parse(url2));
    // Check the response status code
    if (response2.statusCode == 200) {
      //Parse the response JSON
      var data = jsonDecode(response2.body);
      var volumeInfo, title, authors, publisher, publicationYear, description;
      if (data['items'] != null) {
        volumeInfo = data['items'][0]['volumeInfo'];
        if (volumeInfo['title'] != null) title = volumeInfo['title'];
        if (volumeInfo['authors'] != null)
          authors = volumeInfo['authors'][0];
        if (volumeInfo['publisher'] != null)
          publisher = volumeInfo['publisher'];
        if (volumeInfo['publishedDate'] != null)
          publicationYear = volumeInfo['publishedDate'];
        if (volumeInfo['description'] != null)
          description = volumeInfo['description'];
      }

      setState(() {
        if (title != null && _title == "") _title = title;
        if (authors != null && _authors == "") _authors = authors;
        if (publisher != null && _publisher == "") _publisher = publisher;
        if (publicationYear != null && _publicationYear == "")
          _publicationYear = publicationYear;
        if (description != null && _description == "")
          _description = description;
      });
      print('url2 queried');
    } else {
      print('url2 failed');
    }

    // // Make an HTTP GET request to the Abebooks API
    // String url3 = "http://classify.oclc.org/classify2/Classify?isbn=$_isbn&summary=true";
    final url3 = Uri.parse(
        'https://www.abebooks.com/servlet/DWRestService/pricingservice');
    final payload3 = {
      'action': 'getPricingDataByISBN',
      'isbn': _isbn,
      'container': 'pricingService-$_isbn'
    };
    final response3 = await http.post(url3, body: payload3);
    final results = json.decode(response3.body);

    if (results['success']) {
      print(json.decode(response3.body));
      double newPrice, usedPrice, newShipping, usedShipping;

      String bookNew = '', bookUsed = '', destination = '';
      final bestNew = results['pricingInfoForBestNew'];
      final bestUsed = results['pricingInfoForBestUsed'];

      if (bestNew != null) {
        newPrice =
            double.parse(bestNew['bestPriceInPurchaseCurrencyValueOnly']);
        newShipping = double.parse(bestNew[
            'bestShippingToDestinationPriceInPurchaseCurrencyValueOnly']);
        destination = bestNew['shippingDestinationNameInSurferLanguage'];
        bookNew = '${(newPrice + newShipping).toStringAsFixed(2)}';
        print(bookNew);
      }

      if (bestUsed != null) {
        usedPrice =
            double.parse(bestUsed['bestPriceInPurchaseCurrencyValueOnly']);
        usedShipping = double.parse(bestUsed[
            'bestShippingToDestinationPriceInPurchaseCurrencyValueOnly']);
        destination = bestUsed['shippingDestinationNameInSurferLanguage'];
        bookUsed = '${(usedPrice + usedShipping).toStringAsFixed(2)}';
      }

      setState(() {
        if (bookNew != null && _bookNew == "") _bookNew = bookNew;
        if (bookUsed != null && _bookUsed == "") _bookUsed = bookUsed;
        if (destination != null && _destination == "")
          _destination = destination;
      });
      print('url3 queried');
    } else {
      print('url3 failed');
    }

    if (_coverlink == "")
      _coverlink = "https://pictures.abebooks.com/isbn/$_isbn\.jpg";}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xffffffff),
      body: SafeArea(
          child: Column(
            //mainAxisAlignment: MainAxisAlignment.start,
            //crossAxisAlignment: CrossAxisAlignment.center,
            //mainAxisSize: MainAxisSize.max,
            children: [
              Expanded(
                  flex: 5,
                  child: Stack(
                alignment: Alignment.center,
                children: [
                  Align(
                    child:
                    ColorFiltered(
                        colorFilter: ColorFilter.mode(
                            Colors.black.withOpacity(0.5),
                            BlendMode.darken),
                        child: Image(
                          image: NetworkImage(_coverlink),
                          height: MediaQuery.of(context).size.height,
                          width: MediaQuery.of(context).size.width,
                          fit: BoxFit.fitWidth,
                        )),
                  ),
                  Align(
                    child:
                    BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 3, sigmaY: 3),
                      child: Image(
                        image: NetworkImage(_coverlink),
                        height: MediaQuery.of(context).size.height,
                        width: MediaQuery.of(context).size.width,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ],
              ),),
              Expanded(
                flex: 12,
                child: SingleChildScrollView(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 0, horizontal: 20),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      mainAxisSize: MainAxisSize.max,
                      children: [
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Padding(
                            padding: EdgeInsets.fromLTRB(0, 10, 0, 5),
                            child: Text(
                              _title,
                              textAlign: TextAlign.start,
                              overflow: TextOverflow.clip,
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontStyle: FontStyle.normal,
                                fontSize: 24,
                                color: Color(0xff000000),
                              ),
                            ),
                          ),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.max,
                          children: [
                            Expanded(child:Column(
                              mainAxisAlignment: MainAxisAlignment.start,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.max,
                              children: [
                                Text(
                                  _authors,
                                  textAlign: TextAlign.start,
                                  overflow: TextOverflow.clip,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w400,
                                    fontStyle: FontStyle.normal,
                                    color: Color(0xff000000),
                                  ),
                                ),
                                Text(
                                  _publisher,
                                  textAlign: TextAlign.start,
                                  overflow: TextOverflow.clip,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w500,
                                    fontStyle: FontStyle.normal,
                                    color: Color(0xff000000),
                                  ),
                                ),
                              ],
                            ), ),

                            Text(
                              _publicationYear,
                              textAlign: TextAlign.start,
                              overflow: TextOverflow.clip,
                              style: TextStyle(
                                fontWeight: FontWeight.w400,
                                fontStyle: FontStyle.normal,
                                color: Color(0xff000000),
                              ),
                            ),
                          ],
                        ),
                        Container(
                          margin: EdgeInsets.symmetric(vertical: 10, horizontal: 0),
                          padding: EdgeInsets.all(0),
                          width: MediaQuery.of(context).size.width,
                          height: 1,
                          decoration: BoxDecoration(
                            color: Color(0x1f000000),
                            shape: BoxShape.rectangle,
                            borderRadius: BorderRadius.zero,
                            border: Border.all(color: Color(0x4d9e9e9e), width: 1),
                          ),
                        ),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            _description,
                            textAlign: TextAlign.start,
                            overflow: TextOverflow.clip,
                            style: TextStyle(
                              fontWeight: FontWeight.w400,
                              fontStyle: FontStyle.normal,
                              color: Color(0xff000000),
                            ),
                          ),
                        ),
                        Padding(
                          padding: EdgeInsets.fromLTRB(0, 20, 0, 0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            mainAxisSize: MainAxisSize.max,
                            children: [
                              Expanded(
                                flex: 1,
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.start,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  mainAxisSize: MainAxisSize.max,
                                  children: [
                                    Text(
                                      "ISBN",
                                      textAlign: TextAlign.start,
                                      overflow: TextOverflow.clip,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontStyle: FontStyle.normal,
                                        color: Color(0xff000000),
                                      ),
                                    ),
                                    Text(
                                      _isbn,
                                      textAlign: TextAlign.start,
                                      overflow: TextOverflow.clip,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w400,
                                        fontStyle: FontStyle.normal,
                                        color: Color(0xff000000),
                                      ),
                                    ),
                                    Padding(
                                      padding: EdgeInsets.fromLTRB(0, 10, 0, 0),
                                      child: Text(
                                        "New Price",
                                        textAlign: TextAlign.start,
                                        overflow: TextOverflow.clip,
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontStyle: FontStyle.normal,
                                          color: Color(0xff000000),
                                        ),
                                      ),
                                    ),
                                    Text(
                                      "US\$ $_bookNew",
                                      textAlign: TextAlign.start,
                                      overflow: TextOverflow.clip,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w400,
                                        fontStyle: FontStyle.normal,
                                        color: Color(0xff000000),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Expanded(
                                flex: 1,
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.start,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  mainAxisSize: MainAxisSize.max,
                                  children: [
                                    Text(
                                      "DDC",
                                      textAlign: TextAlign.start,
                                      overflow: TextOverflow.clip,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontStyle: FontStyle.normal,
                                        color: Color(0xff000000),
                                      ),
                                    ),
                                    Text(
                                      _ddc,
                                      textAlign: TextAlign.start,
                                      overflow: TextOverflow.clip,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w400,
                                        fontStyle: FontStyle.normal,
                                        color: Color(0xff000000),
                                      ),
                                    ),
                                    Padding(
                                      padding: EdgeInsets.fromLTRB(0, 10, 0, 0),
                                      child: Text(
                                        "Used Price",
                                        textAlign: TextAlign.start,
                                        overflow: TextOverflow.clip,
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontStyle: FontStyle.normal,
                                          color: Color(0xff000000),
                                        ),
                                      ),
                                    ),
                                    Text(
                                      "US\$ $_bookUsed",
                                      textAlign: TextAlign.start,
                                      overflow: TextOverflow.clip,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w400,
                                        fontStyle: FontStyle.normal,
                                        color: Color(0xff000000),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding:
                          EdgeInsets.symmetric(vertical: 20, horizontal: 0),
                          child: Text(
                            "Prices from Abebooks, Shipping to $_destination",
                            textAlign: TextAlign.start,
                            overflow: TextOverflow.clip,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontStyle: FontStyle.normal,
                              color: Color(0xff000000),
                            ),
                          ),
                        ),
                        Padding(
                          padding: EdgeInsets.fromLTRB(0, 0, 0, 100),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            mainAxisSize: MainAxisSize.max,
                            children: [
                              Expanded(
                                flex: 1,
                                child: Padding(
                                  padding: EdgeInsets.symmetric(
                                      vertical: 0, horizontal: 10),
                                  child: FilledButton(
                                    onPressed: () {
                                      launch(
                                          'https://www.bookfinder.com/isbn/$_isbn/');
                                    },
                                    style: ButtonStyle(
                                      padding: MaterialStateProperty.all(EdgeInsets.all(12)),
                                    ),
                                    child: Text(
                                      "Search Bookfinder",
                                      style: TextStyle(
                                        fontWeight: FontWeight.w400,
                                        fontStyle: FontStyle.normal,
                                      ),
                                      maxLines: 2,
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 1,
                                child: Padding(
                                  padding: EdgeInsets.symmetric(
                                      vertical: 0, horizontal: 10),
                                  child: FilledButton(
                                    onPressed: () {
                                      launch(
                                          'https://www.abebooks.com/servlet/SearchResults?kn=$_isbn');
                                    },
                                    style: ButtonStyle(
                                      padding: MaterialStateProperty.all(EdgeInsets.all(12)),
                                    ),
                                    child: Text(
                                      "Search Abebooks",
                                      style: TextStyle(
                                        fontWeight: FontWeight.w400,
                                        fontStyle: FontStyle.normal,
                                      ),
                                      maxLines: 2,
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 1,
                                child: Padding(
                                  padding: EdgeInsets.symmetric(
                                      vertical: 0, horizontal: 10),
                                  child: FilledButton(
                                    onPressed: () {
                                      launch(
                                          'https://flinders.primo.exlibrisgroup.com/discovery/search?query=any,contains,$_isbn&vid=61FUL_INST:FUL&tab=Everything&facet=rtype,exclude,reviews');
                                    },
                                    style: ButtonStyle(
                                      padding: MaterialStateProperty.all(EdgeInsets.all(12)),
                                    ),
                                    child: Text(
                                      "Search Findit\u200b@Flinders",
                                      style: TextStyle(
                                        fontWeight: FontWeight.w400,
                                        fontStyle: FontStyle.normal,
                                      ),
                                      maxLines: 3,
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          )),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Navigate back to the main page
          Navigator.popUntil(context, ModalRoute.withName('/'));
        },
        child: Icon(Icons.arrow_back),
      ),
    );
  }
}