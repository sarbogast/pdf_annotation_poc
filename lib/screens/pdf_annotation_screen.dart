import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

bool kIsDesktop = kIsWeb || Platform.isMacOS || Platform.isWindows;

class PdfAnnotationScreen extends StatefulWidget {
  const PdfAnnotationScreen({super.key});

  @override
  State<PdfAnnotationScreen> createState() => _PdfAnnotationScreenState();
}

class _PdfAnnotationScreenState extends State<PdfAnnotationScreen> {
  final _annotationLayerName = '__annotations__';
  final PdfViewerController _controller = PdfViewerController();
  final double _pageSpacing = 4;
  Offset _scrollOffset = Offset.zero;
  Offset? _scrollOffsetBeforeDocumentUpdate;
  Uint8List? _documentBytes;

  @override
  void initState() {
    _controller.addListener(() {
      _scrollOffset = _controller.scrollOffset;
      debugPrint('Scroll offset: $_scrollOffset');
    });
    super.initState();
    _loadDocument();
  }

  Future<void> _loadDocument() async {
    final byteData = await rootBundle.load('assets/pdf/flutter-succinctly.pdf');
    setState(() {
      _documentBytes = byteData.buffer.asUint8List();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  BoxConstraints _getViewportConstraints() {
    return context.findRenderObject()!.constraints as BoxConstraints;
  }

  // Gets the size of the PDF page in the SfPdfViewer
  Size _getPageSizeInViewport(context, document) {
    final viewportConstraints = _getViewportConstraints();
    Size pageSize;
    if (!kIsDesktop) {
      BoxConstraints constraints = BoxConstraints(
        maxWidth: viewportConstraints.maxWidth,
      );
      constraints = BoxConstraints.tightFor(
        width: viewportConstraints.maxWidth,
      ).enforce(constraints);
      pageSize = constraints.constrainSizeAndAttemptToPreserveAspectRatio(
        Size(
          document.pages[0].size.width,
          document.pages[0].size.height,
        ),
      );
    } else {
      pageSize = Size(
        document.pages[0].size.width,
        document.pages[0].size.height,
      );
    }
    return pageSize;
  }

  Future<void> _annotate(TapDownDetails details) async {
    final localPosition = details.localPosition;
    debugPrint('Tapped at $localPosition');

    // PDF loaded document instance
    final document = PdfDocument(inputBytes: _documentBytes);

    // Calculates the size of the PDF page.
    // ignore: use_build_context_synchronously
    Size calculatedSize = _getPageSizeInViewport(context, document);
    double pageHeight = calculatedSize.height + _pageSpacing;
    double pageWidth = calculatedSize.width;

    // Gets the page number on which the tap has been made
    double value =
        (_controller.scrollOffset.dy + localPosition.dy) / pageHeight;
    int pageNumber = value.toInt();

    // Gets the PDF page instance to which the text need to be added.
    final page = document.pages[pageNumber];

    // Calculates the scaled page height and width percentage w.r.t the original size.
    final heightPercentage = page.size.height / pageHeight;
    final widthPercentage = page.size.width / pageWidth;

    // Y offset relative to the PDF page.
    double adjustedDY = localPosition.dy / _controller.zoomLevel -
        ((pageHeight * pageNumber) - _controller.scrollOffset.dy);
    adjustedDY = kIsDesktop ? adjustedDY : adjustedDY * heightPercentage;

    final viewportConstraints = _getViewportConstraints();
    double extraGrayArea = (viewportConstraints.biggest.width -
            (pageWidth * _controller.zoomLevel)) /
        (2 * _controller.zoomLevel);

    // X offset relative to the PDF page.
    double adjustedDX = (viewportConstraints.biggest.width >
            (pageWidth * _controller.zoomLevel))
        ? (localPosition.dx / _controller.zoomLevel) - extraGrayArea
        : localPosition.dx / _controller.zoomLevel;
    adjustedDX = adjustedDX + _controller.scrollOffset.dx;
    adjustedDX = kIsDesktop ? adjustedDX : adjustedDX * widthPercentage;

    debugPrint(
        'Tapped at document coordinates: $adjustedDX, $adjustedDY in page $pageNumber');

    debugPrint(('Number of layers: ${page.layers.count}'));
    PdfPageLayer layer;

    if (page.layers.count == 0) {
      layer = page.layers.add(name: _annotationLayerName, visible: true);
    } else {
      layer = page.layers[page.layers.count - 1];
      if (layer.name != _annotationLayerName) {
        layer = page.layers.add(name: _annotationLayerName, visible: true);
      }
    }
    layer.graphics.drawRectangle(
      bounds: Rect.fromLTWH(adjustedDX, adjustedDY, 50, 50),
      brush: PdfSolidBrush(
        PdfColor(0, 0, 255),
      ),
    );

    /*page.graphics.drawRectangle(
      bounds: Rect.fromLTWH(adjustedDX, adjustedDY, 50, 50),
      brush: PdfSolidBrush(
        PdfColor(0, 0, 255),
      ),
    );*/

    final newDocumentBytes = await document.save();
    // Remember scroll offset before updating document and thus resetting it
    final scrollOffset = _scrollOffset;
    setState(() {
      _documentBytes = Uint8List.fromList(newDocumentBytes);
    });
    // wait for rebuild to be complete
    Future.delayed(const Duration(milliseconds: 25), () {
      _controller.jumpTo(
        xOffset: scrollOffset.dx,
        yOffset: scrollOffset.dy,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('PDF Annotation Screen'),
        actions: [
          IconButton(
            icon: const Icon(Icons.abc),
            onPressed: () => _controller.jumpTo(
              xOffset: 0,
              yOffset: 200,
            ),
          ),
        ],
      ),
      body: _documentBytes == null
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : RawGestureDetector(
              gestures: {
                TapGestureRecognizer:
                    GestureRecognizerFactoryWithHandlers<TapGestureRecognizer>(
                  () => TapGestureRecognizer(),
                  //constructor
                  (TapGestureRecognizer instance) {
                    instance.onTapDown = _annotate;
                  },
                )
              },
              child: SfPdfViewer.memory(
                _documentBytes!,
                controller: _controller,
                pageSpacing: _pageSpacing,
                enableTextSelection: false,
                enableDocumentLinkAnnotation: false,
                enableHyperlinkNavigation: false,
              ),
            ),
    );
  }
}
