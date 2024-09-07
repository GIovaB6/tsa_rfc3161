import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:asn1lib/asn1lib.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import 'tsa_hash_algo.dart';

class TSARequest {
  late ASN1Sequence _asn1sequence;

  late int algorithm;
  int? nonce;
  bool? certReq;

  String? filepath;

  TSARequest();

  ASN1Sequence get asn1sequence {
    return _asn1sequence;
  }

  Future<Response> run({required String hostname, String? credentials}) async {
    // send request to TSA Server

    Map<String, dynamic> headers = {
      'Content-Type': 'application/timestamp-query'
    };

    if (credentials != null) {
      String basicAuth = 'Basic ${base64.encode(utf8.encode(credentials))}';
      headers.addAll({'authorization': basicAuth});
    }

    Options options = Options(headers: headers);

    final dio = Dio();

    // call digicert's timestamp server
    String tsaUrl = hostname; // URL du serveur TSA

    try {
      Response response = await dio.post(tsaUrl,
          data: asn1sequence.encodedBytes, options: options);

      return response;
    } on DioException catch (e) {
      if (e.response != null) {
        return e.response!;
      } else {
        rethrow;
      }
    } on Exception {
      rethrow;
    }
  }

  TSARequest.fromFile(
      {required this.filepath,
      required this.algorithm,
      this.nonce,
      this.certReq}) {
    File file = File(filepath!);
    List<int> fileBytes = file.readAsBytesSync();
    //
    ASN1Sequence messageImprint =
        _getSeqMessageImprintSequence(message: fileBytes, algorithm: algorithm);

    _init(messageImprint: messageImprint, nonce: nonce, certReq: certReq);
  }

  TSARequest.fromString(
      {required String s, required this.algorithm, this.nonce, this.certReq}) {
    //
    ASN1Sequence messageImprint = _getSeqMessageImprintSequence(
        message: s.codeUnits, algorithm: algorithm);

    _init(messageImprint: messageImprint, nonce: nonce, certReq: certReq);
  }

  void _init(
      {required ASN1Sequence messageImprint, int? nonce, bool? certReq}) {
    ASN1Integer version = ASN1Integer.fromInt(1);
    ASN1Sequence timeStampReq = ASN1Sequence();

    timeStampReq.add(version);
    timeStampReq.add(messageImprint);

    // policyId
    // timeStampReq.add(ASN1Null());

    if (nonce != null) {
      ASN1Integer asn1nonce = ASN1Integer(BigInt.from(nonce));
      timeStampReq.add(asn1nonce);
      //  should be similar to 02 08 38 8e bc 2c d8 bf 32 41
      //                       02 08 61 d0 dd 7e 47 a9 16 0a
    }
    if (certReq != null) {
      ASN1Boolean asncertReq = ASN1Boolean(
          certReq); // Demande d'inclusion des certificats dans la réponse
      timeStampReq.add(asncertReq);
    }

    _asn1sequence = timeStampReq;
  }

  static _getSeqMessageImprintSequence(
      {required List<int> message, required int algorithm}) {
    //
    // seqAlgorithm

    ASN1Sequence seqAlgorithm;
    ASN1Object hashedText;
    switch (algorithm) {
      case TSAHashAlgo.sha256:
        seqAlgorithm = TSAHashAlgoSHA256.getASN1Sequence();
        hashedText = TSAHashAlgoSHA256.getASN1ObjectHashed(message: message);
        break;
      default:
        seqAlgorithm = TSAHashAlgoSHA256.getASN1Sequence();
        hashedText = TSAHashAlgoSHA256.getASN1ObjectHashed(message: message);
    }

    //
    ASN1Sequence messageImprintSequence = ASN1Sequence();
    messageImprintSequence.add(seqAlgorithm);
    messageImprintSequence.add(hashedText);
    return messageImprintSequence;
  }

  void hexaPrint() {
    Uint8List data = asn1sequence.encodedBytes;
    var hex2 =
        data.map((e) => "${e.toRadixString(16).padLeft(2, '0')} ").join();
    debugPrint(hex2);
  }

  write(String filename) async {
    try {
      Uint8List data = asn1sequence.encodedBytes;
      var hex2 =
          data.map((e) => "${e.toRadixString(16).padLeft(2, '0')} ").join();
      debugPrint(hex2);

      Directory root = await getTemporaryDirectory();
      File file = await File('${root.path}/$filename').create();
      debugPrint(file.path);
      file.writeAsBytesSync(data);
    } catch (e) {
      debugPrint(e.toString());
    }
  }
}
