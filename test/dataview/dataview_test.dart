library bwu_dart.bwu_datagrid.dataview.test;

import 'dart:async' as async;

import 'package:unittest/unittest.dart';
import 'package:unittest/html_config.dart';
import 'package:bwu_datagrid/dataview/dataview.dart';
//import 'package:bwu_datagrid/datagrid/helpers.dart';
import 'package:bwu_datagrid/core/core.dart' as core;
import 'package:bwu_datagrid/datagrid/helpers.dart';

import 'package:logging/logging.dart';
import 'package:quiver_log/log.dart';

var _log = new Logger('bwu_datagrid.dataview_test');

void assertEmpty(DataView dv) {
  expect(0, equals(dv.length), reason: ".rows is initialized to an empty array");
  expect(dv.getItems().length, equals(0), reason: "getItems().length");
  expect(dv.getIdxById("id"), isNull, reason: "getIdxById should return undefined if not found");
  expect(dv.getRowById("id"), isNull, reason: "getRowById should return undefined if not found");
  expect(dv.getItemById("id"), isNull, reason: "getItemById should return undefined if not found");
  expect(dv.getItemByIdx(0), isNull, reason: "getItemByIdx should return undefined if not found");
}


void assertConsistency(DataView dv, [String idProperty]) {
  if(idProperty == null || idProperty.isEmpty) {
    idProperty = "id";
  }
  List<core.ItemBase> items = dv.getItems();
      int filteredOut = 0;
      int row;
      String id;

  for (var i = 0; i < items.length; i++) {
      id = '${items[i][idProperty]}';
      expect(dv.getItemByIdx(i), equals(items[i]), reason: "getItemByIdx");
      expect(dv.getItemById(id), equals(items[i]), reason: "getItemById");
      expect(dv.getIdxById(id), equals(i), reason: "getIdxById");

      row = dv.getRowById(id);
      if (row == null) {
          filteredOut++;
      }      else {
          expect(dv.getItem(row), equals(items[i]), reason: "getRowById");
      }
  }

  expect(items.length - dv.length, equals(filteredOut), reason: "filtered rows");
}

void main() {
  Logger.root.level = Level.ALL;
  new PrintAppender(BASIC_LOG_FORMATTER).attachLogger(_log);

  useHtmlConfiguration();

    group('basic', () {
      test("initial setup", () {
        var dv = new DataView();
        assertEmpty(dv);
      });

      test("initial setup, refresh", () {
          var dv = new DataView();
          dv.refresh();
          assertEmpty(dv);
      });
    });


    group('setItems', () {
      test("empty", () {
          var dv = new DataView();
          dv.setItems([]);
          assertEmpty(dv);
      });

      test("basic", () {
          var dv = new DataView();
          dv.setItems([new MapDataItem({'id':0}), new MapDataItem({'id':1})]);
          expect(dv.length, equals(2), reason: "rows.length");
          expect(dv.getItems().length, equals(2), reason: "getItems().length");
          assertConsistency(dv);
      });

      test("alternative idProperty", () {
          var dv = new DataView();
          dv.setItems([new MapDataItem({'uid':0}),new MapDataItem({'uid':1})], "uid");
          assertConsistency(dv,"uid");
      });

      // TODO a bug makes the debugger stop at caught exceptions, this is annoying
      skip_test("requires an id on objects", () {
          var dv = new DataView();
          expect(() => dv.setItems([1,2,3]), throwsNoSuchMethodError,
              reason:  "exception expected");
      });

// TODO a bug makes the debugger stop at caught exceptions, this is annoying
      skip_test("requires a unique id on objects", () {
          var dv = new DataView();
              expect(() => dv.setItems([new MapDataItem({'id':0}), new MapDataItem({'id':0})]),
                  throwsA(new isInstanceOf<String>()), reason: "exception expected");
      });

// TODO a bug makes the debugger stop at caught exceptions, this is annoying
      skip_test("requires a unique id on objects (alternative idProperty)", () {
          var dv = new DataView();
              expect(() => dv.setItems([{'uid':0},{'uid':0}], "uid"), throwsA(new isInstanceOf<String>())); //ok(false, "exception expected")
      });

      test("events fired on setItems", () {
        var dv = new DataView();
        var done = expectAsync((){}, count: 3);

        dv.onBwuRowsChanged.listen((e) {
          done();
        });
        dv.onBwuRowCountChanged.listen((e) {
          expect(e.oldCount, equals(0), reason: "previous arg");
          expect(e.newCount, equals(2), reason: "current arg");
          done();
        });
        dv.onBwuPagingInfoChanged.listen((e) {
          expect(e.pagingInfo.pageSize, equals(0), reason: "pageSize arg");
          expect(e.pagingInfo.pageNum, equals(0), reason: "pageNum arg");
          expect(e.pagingInfo.totalRows, equals(2), reason: "totalRows arg");
          done();
        });
        dv.setItems([new MapDataItem({'id': 0}), new MapDataItem({'id': 1})]);
        dv.refresh();
      });

      test("no events on setItems([])", () {
        var dv = new DataView();
        dv.onBwuRowsChanged.listen((_) => fail("onRowsChanged called"));
        dv.onBwuRowCountChanged.listen((_) => fail("onRowCountChanged called"));
        dv.onBwuPagingInfoChanged.listen((_) => fail("onPagingInfoChanged called"));
        dv.setItems([]);
        dv.refresh();
        return new async.Future((){});
      });

      test("no events on setItems followed by refresh", () {
        var dv = new DataView();
        dv.setItems([new MapDataItem({'id':0}), new MapDataItem({'id':1})]);
        dv.onBwuRowsChanged.listen((_) => fail("onRowsChanged called"));
        dv.onBwuRowCountChanged.listen((_) => fail("onRowCountChanged called"));
        dv.onBwuPagingInfoChanged.listen((_) => ("onPagingInfoChanged called"));
        dv.refresh();
        return new async.Future((){});
      });

      test("no refresh while suspended", () {
        var dv = new DataView();
        dv.beginUpdate();
        dv.onBwuRowsChanged.listen((_) => fail("onRowsChanged called"));
        dv.onBwuRowCountChanged.listen((_) => fail("onRowCountChanged called"));
        dv.onBwuPagingInfoChanged.listen((_) => fail("onPagingInfoChanged called"));
        dv.setItems([new MapDataItem({'id':0}),new MapDataItem({'id':1})]);
        dv.setFilter((a, b) => true);
        dv.refresh();
        expect(dv.length, equals(0), reason: "rows aren't updated until resumed");
      });

      test("refresh fires after resume", () {
        var dv = new DataView();
        dv.beginUpdate();
        dv.setItems([new MapDataItem({'id':0}), new MapDataItem({'id':1})]);
        expect(dv.items.length, equals(2), reason: "items updated immediately");
        dv.setFilter((a, b) => true);
        dv.refresh();

        var done = expectAsync((){}, count: 3);
        dv.onBwuRowsChanged.listen((e) {
          expect(e.changedRows, equals([0,1]), reason: "args");
          done();
        });
        dv.onBwuRowCountChanged.listen((e) {
          expect(e.oldCount, equals(0), reason: "previous arg");
          expect(e.newCount, equals(2), reason: "current arg");
          done();
        });
        dv.onBwuPagingInfoChanged.listen((e) {
          expect(e.pagingInfo.pageSize, equals(0), reason: "pageSize arg");
          expect(e.pagingInfo.pageNum, equals(0), reason: "pageNum arg");
          expect(e.pagingInfo.totalRows, equals(2), reason: "totalRows arg");
          done();
        });
        dv.endUpdate();
        expect(dv.items.length, equals(2), reason: "items are the same");
        expect(dv.length, equals(2), reason: "rows updated");
      });

    });


    group("sort", () {

      test("happy path", () {
        var items = [new MapDataItem({'id': 2,'val': 2}), new MapDataItem({'id': 1, 'val': 1}), new MapDataItem({'id': 0, 'val':0})];
        var dv = new DataView();
        dv.setItems(items);
        var done = expectAsync((){});
        dv.onBwuRowsChanged.listen((_) {
          print('x');
          done();
        });
        dv.onBwuRowCountChanged.listen((e) => fail("onRowCountChanged called"));
        dv.onBwuPagingInfoChanged.listen((e) => fail("onPagingInfoChanged called"));
        dv.sort((x,y) {
          return x['val'] - y['val'];
        }, true);
        expect(dv.items, equals(items), reason: "original array should get sorted");
        expect(items, equals([new MapDataItem({'id': 0, 'val': 0}), new MapDataItem({'id': 1, 'val': 1}), new MapDataItem({'id': 2, 'val': 2})]), reason: "sort order");
        assertConsistency(dv);
      });

//test("asc by default", function() {
//    var items = [{id:2,val:2},{id:1,val:1},{id:0,val:0}];
//    var dv = new Slick.Data.DataView();
//    dv.setItems(items);
//    dv.sort(function(x,y) { return x.val-y.val });
//    same(items, [{id:0,val:0},{id:1,val:1},{id:2,val:2}], "sort order");
//});
//
//test("desc", function() {
//    var items = [{id:0,val:0},{id:2,val:2},{id:1,val:1}];
//    var dv = new Slick.Data.DataView();
//    dv.setItems(items);
//    dv.sort(function(x,y) { return -1*(x.val-y.val) });
//    same(items, [{id:2,val:2},{id:1,val:1},{id:0,val:0}], "sort order");
//});
//
//test("sort is stable", function() {
//    var items = [{id:0,val:0},{id:2,val:2},{id:3,val:2},{id:1,val:1}];
//    var dv = new Slick.Data.DataView();
//    dv.setItems(items);
//
//    dv.sort(function(x,y) { return x.val-y.val });
//    same(items, [{id:0,val:0},{id:1,val:1},{id:2,val:2},{id:3,val:2}], "sort order");
//
//    dv.sort(function(x,y) { return x.val-y.val });
//    same(items, [{id:0,val:0},{id:1,val:1},{id:2,val:2},{id:3,val:2}], "sorting on the same column again doesn't change the order");
//
//    dv.sort(function(x,y) { return -1*(x.val-y.val) });
//    same(items, [{id:2,val:2},{id:3,val:2},{id:1,val:1},{id:0,val:0}], "sort order");
//});
//
//
//module("filtering");
//
//test("applied immediately", function() {
//    var count = 0;
//    var dv = new Slick.Data.DataView();
//    dv.setItems([{id:0,val:0},{id:1,val:1},{id:2,val:2}]);
//    dv.onRowsChanged.subscribe(function(e,args) {
//        ok(true, "onRowsChanged called");
//        same(args, {rows:[0]}, "args");
//        count++;
//    });
//    dv.onRowCountChanged.subscribe(function(e,args) {
//        ok(true, "onRowCountChanged called");
//        same(args.previous, 3, "previous arg");
//        same(args.current, 1, "current arg");
//        count++;
//    });
//    dv.onPagingInfoChanged.subscribe(function(e,args) {
//        ok(true, "onPagingInfoChanged called");
//        same(args.pageSize, 0, "pageSize arg");
//        same(args.pageNum, 0, "pageNum arg");
//        same(args.totalRows, 1, "totalRows arg");
//        count++;
//    });
//    dv.setFilter(function(o) { return o.val === 1; });
//    equal(count, 3, "events fired");
//    same(dv.getItems().length, 3, "original data is still there");
//    same(dv.getLength(), 1, "rows are filtered");
//    assertConsistency(dv);
//});
//
//test("re-applied on refresh", function() {
//    var count = 0;
//    var dv = new Slick.Data.DataView();
//    dv.setItems([{id:0,val:0},{id:1,val:1},{id:2,val:2}]);
//    dv.setFilterArgs(0);
//    dv.setFilter(function(o, args) { return o.val >= args; });
//    same(dv.getLength(), 3, "nothing is filtered out");
//    assertConsistency(dv);
//
//    dv.onRowsChanged.subscribe(function(e,args) {
//        ok(true, "onRowsChanged called");
//        same(args, {rows:[0]}, "args");
//        count++;
//    });
//    dv.onRowCountChanged.subscribe(function(e,args) {
//        ok(true, "onRowCountChanged called");
//        same(args.previous, 3, "previous arg");
//        same(args.current, 1, "current arg");
//        count++;
//    });
//    dv.onPagingInfoChanged.subscribe(function(e,args) {
//        ok(true, "onPagingInfoChanged called");
//        same(args.pageSize, 0, "pageSize arg");
//        same(args.pageNum, 0, "pageNum arg");
//        same(args.totalRows, 1, "totalRows arg");
//        count++;
//    });
//    dv.setFilterArgs(2);
//    dv.refresh();
//    equal(count, 3, "events fired");
//    same(dv.getItems().length, 3, "original data is still there");
//    same(dv.getLength(), 1, "rows are filtered");
//    assertConsistency(dv);
//});
//
//test("re-applied on sort", function() {
//    var dv = new Slick.Data.DataView();
//    dv.setItems([{id:0,val:0},{id:1,val:1},{id:2,val:2}]);
//    dv.setFilter(function(o) { return o.val === 1; });
//    same(dv.getLength(), 1, "one row is remaining");
//
//    dv.onRowsChanged.subscribe(function() { ok(false, "onRowsChanged called") });
//    dv.onRowCountChanged.subscribe(function() { ok(false, "onRowCountChanged called") });
//    dv.onPagingInfoChanged.subscribe(function() { ok(false, "onPagingInfoChanged called") });
//    dv.sort(function(x,y) { return x.val-y.val; }, false);
//    same(dv.getItems().length, 3, "original data is still there");
//    same(dv.getLength(), 1, "rows are filtered");
//    assertConsistency(dv);
//});
//
//test("all", function() {
//    var count = 0;
//    var dv = new Slick.Data.DataView();
//    dv.setItems([{id:0,val:0},{id:1,val:1},{id:2,val:2}]);
//    dv.onRowsChanged.subscribe(function(e,args) {
//        ok(false, "onRowsChanged called");
//    });
//    dv.onRowCountChanged.subscribe(function(e,args) {
//        ok(true, "onRowCountChanged called");
//        same(args.previous, 3, "previous arg");
//        same(args.current, 0, "current arg");
//        count++;
//    });
//    dv.onPagingInfoChanged.subscribe(function(e,args) {
//        ok(true, "onPagingInfoChanged called");
//        same(args.pageSize, 0, "pageSize arg");
//        same(args.pageNum, 0, "pageNum arg");
//        same(args.totalRows, 0, "totalRows arg");
//        count++;
//    });
//    dv.setFilter(function(o) { return false; });
//    equal(count, 2, "events fired");
//    same(dv.getItems().length, 3, "original data is still there");
//    same(dv.getLength(), 0, "rows are filtered");
//    assertConsistency(dv);
//});
//
//test("all then none", function() {
//    var count = 0;
//    var dv = new Slick.Data.DataView();
//    dv.setItems([{id:0,val:0},{id:1,val:1},{id:2,val:2}]);
//    dv.setFilterArgs(false);
//    dv.setFilter(function(o, args) { return args; });
//    same(dv.getLength(), 0, "all rows are filtered out");
//
//    dv.onRowsChanged.subscribe(function(e,args) {
//        ok(true, "onRowsChanged called");
//        same(args, {rows:[0,1,2]}, "args");
//        count++;
//    });
//    dv.onRowCountChanged.subscribe(function(e,args) {
//        ok(true, "onRowCountChanged called");
//        same(args.previous, 0, "previous arg");
//        same(args.current, 3, "current arg");
//        count++;
//    });
//    dv.onPagingInfoChanged.subscribe(function(e,args) {
//        ok(true, "onPagingInfoChanged called");
//        same(args.pageSize, 0, "pageSize arg");
//        same(args.pageNum, 0, "pageNum arg");
//        same(args.totalRows, 3, "totalRows arg");
//        count++;
//    });
//    dv.setFilterArgs(true);
//    dv.refresh();
//    equal(count, 3, "events fired");
//    same(dv.getItems().length, 3, "original data is still there");
//    same(dv.getLength(), 3, "all rows are back");
//    assertConsistency(dv);
//});
//
//test("inlining replaces absolute returns", function() {
//    var dv = new Slick.Data.DataView({ inlineFilters: true });
//    dv.setItems([{id:0,val:0},{id:1,val:1},{id:2,val:2}]);
//    dv.setFilter(function(o) {
//        if (o.val === 1) { return true; }
//        else if (o.val === 4) { return true }
//        return false});
//    same(dv.getLength(), 1, "one row is remaining");
//
//    dv.onRowsChanged.subscribe(function() { ok(false, "onRowsChanged called") });
//    dv.onRowCountChanged.subscribe(function() { ok(false, "onRowCountChanged called") });
//    dv.onPagingInfoChanged.subscribe(function() { ok(false, "onPagingInfoChanged called") });
//    same(dv.getItems().length, 3, "original data is still there");
//    same(dv.getLength(), 1, "rows are filtered");
//    assertConsistency(dv);
//});
//
//test("inlining replaces evaluated returns", function() {
//    var dv = new Slick.Data.DataView({ inlineFilters: true });
//    dv.setItems([{id:0,val:0},{id:1,val:1},{id:2,val:2}]);
//    dv.setFilter(function(o) {
//        if (o.val === 0) { return o.id === 2; }
//        else if (o.val === 1) { return o.id === 2 }
//        return o.val === 2});
//    same(dv.getLength(), 1, "one row is remaining");
//
//    dv.onRowsChanged.subscribe(function() { ok(false, "onRowsChanged called") });
//    dv.onRowCountChanged.subscribe(function() { ok(false, "onRowCountChanged called") });
//    dv.onPagingInfoChanged.subscribe(function() { ok(false, "onPagingInfoChanged called") });
//    same(dv.getItems().length, 3, "original data is still there");
//    same(dv.getLength(), 1, "rows are filtered");
//    assertConsistency(dv);
//});
//
//module("updateItem");
//
//test("basic", function() {
//    var count = 0;
//    var dv = new Slick.Data.DataView();
//    dv.setItems([{id:0,val:0},{id:1,val:1},{id:2,val:2}]);
//
//    dv.onRowsChanged.subscribe(function(e,args) {
//        ok(true, "onRowsChanged called");
//        same(args, {rows:[1]}, "args");
//        count++;
//    });
//    dv.onRowCountChanged.subscribe(function(e,args) {
//        ok(false, "onRowCountChanged called");
//    });
//    dv.onPagingInfoChanged.subscribe(function(e,args) {
//        ok(false, "onPagingInfoChanged called");
//    });
//
//    dv.updateItem(1,{id:1,val:1337});
//    equal(count, 1, "events fired");
//    same(dv.getItem(1), {id:1,val:1337}, "item updated");
//    assertConsistency(dv);
//});
//
//test("updating an item not passing the filter", function() {
//    var dv = new Slick.Data.DataView();
//    dv.setItems([{id:0,val:0},{id:1,val:1},{id:2,val:2},{id:3,val:1337}]);
//    dv.setFilter(function(o) { return o["val"] !== 1337; });
//    dv.onRowsChanged.subscribe(function(e,args) {
//        ok(false, "onRowsChanged called");
//    });
//    dv.onRowCountChanged.subscribe(function(e,args) {
//        ok(false, "onRowCountChanged called");
//    });
//    dv.onPagingInfoChanged.subscribe(function(e,args) {
//        ok(false, "onPagingInfoChanged called");
//    });
//    dv.updateItem(3,{id:3,val:1337});
//    same(dv.getItems()[3], {id:3,val:1337}, "item updated");
//    assertConsistency(dv);
//});
//
//test("updating an item to pass the filter", function() {
//    var count = 0;
//    var dv = new Slick.Data.DataView();
//    dv.setItems([{id:0,val:0},{id:1,val:1},{id:2,val:2},{id:3,val:1337}]);
//    dv.setFilter(function(o) { return o["val"] !== 1337; });
//    dv.onRowsChanged.subscribe(function(e,args) {
//        ok(true, "onRowsChanged called");
//        same(args, {rows:[3]}, "args");
//        count++;
//    });
//    dv.onRowCountChanged.subscribe(function(e,args) {
//        ok(true, "onRowCountChanged called");
//        equal(args.previous, 3, "previous arg");
//        equal(args.current, 4, "current arg");
//        count++;
//    });
//    dv.onPagingInfoChanged.subscribe(function(e,args) {
//        ok(true, "onPagingInfoChanged called");
//        same(args.pageSize, 0, "pageSize arg");
//        same(args.pageNum, 0, "pageNum arg");
//        same(args.totalRows, 4, "totalRows arg");
//        count++;
//    });
//    dv.updateItem(3,{id:3,val:3});
//    equal(count, 3, "events fired");
//    same(dv.getItems()[3], {id:3,val:3}, "item updated");
//    assertConsistency(dv);
//});
//
//test("updating an item to not pass the filter", function() {
//    var count = 0;
//    var dv = new Slick.Data.DataView();
//    dv.setItems([{id:0,val:0},{id:1,val:1},{id:2,val:2},{id:3,val:3}]);
//    dv.setFilter(function(o) { return o["val"] !== 1337; });
//    dv.onRowsChanged.subscribe(function(e,args) {
//        console.log(args)
//        ok(false, "onRowsChanged called");
//    });
//    dv.onRowCountChanged.subscribe(function(e,args) {
//        ok(true, "onRowCountChanged called");
//        equal(args.previous, 4, "previous arg");
//        equal(args.current, 3, "current arg");
//        count++;
//    });
//    dv.onPagingInfoChanged.subscribe(function(e,args) {
//        ok(true, "onPagingInfoChanged called");
//        same(args.pageSize, 0, "pageSize arg");
//        same(args.pageNum, 0, "pageNum arg");
//        same(args.totalRows, 3, "totalRows arg");
//        count++;
//    });
//    dv.updateItem(3,{id:3,val:1337});
//    equal(count, 2, "events fired");
//    same(dv.getItems()[3], {id:3,val:1337}, "item updated");
//    assertConsistency(dv);
//});
//
//
//module("addItem");
//
//test("must have id", function() {
//    var count = 0;
//    var dv = new Slick.Data.DataView();
//    dv.setItems([{id:0,val:0},{id:1,val:1},{id:2,val:2}]);
//    try {
//        dv.addItem({val:1337});
//        ok(false, "exception thrown");
//    }
//    catch (ex) {}
//});
//
//test("must have id (custom)", function() {
//    var count = 0;
//    var dv = new Slick.Data.DataView();
//    dv.setItems([{uid:0,val:0},{uid:1,val:1},{uid:2,val:2}], "uid");
//    try {
//        dv.addItem({id:3,val:1337});
//        ok(false, "exception thrown");
//    }
//    catch (ex) {}
//});
//
//test("basic", function() {
//    var count = 0;
//    var dv = new Slick.Data.DataView();
//    dv.setItems([{id:0,val:0},{id:1,val:1},{id:2,val:2}]);
//    dv.onRowsChanged.subscribe(function(e,args) {
//        ok(true, "onRowsChanged called");
//        same(args, {rows:[3]}, "args");
//        count++;
//    });
//    dv.onRowCountChanged.subscribe(function(e,args) {
//        ok(true, "onRowCountChanged called");
//        equal(args.previous, 3, "previous arg");
//        equal(args.current, 4, "current arg");
//        count++;
//    });
//    dv.onPagingInfoChanged.subscribe(function(e,args) {
//        ok(true, "onPagingInfoChanged called");
//        equal(args.pageSize, 0, "pageSize arg");
//        equal(args.pageNum, 0, "pageNum arg");
//        equal(args.totalRows, 4, "totalRows arg");
//        count++;
//    });
//    dv.addItem({id:3,val:1337});
//    equal(count, 3, "events fired");
//    same(dv.getItems()[3], {id:3,val:1337}, "item updated");
//    same(dv.getItem(3), {id:3,val:1337}, "item updated");
//    assertConsistency(dv);
//});
//
//test("add an item not passing the filter", function() {
//    var dv = new Slick.Data.DataView();
//    dv.setItems([{id:0,val:0},{id:1,val:1},{id:2,val:2}]);
//    dv.setFilter(function(o) { return o["val"] !== 1337; });
//    dv.onRowsChanged.subscribe(function(e,args) {
//        ok(false, "onRowsChanged called");
//    });
//    dv.onRowCountChanged.subscribe(function(e,args) {
//        ok(false, "onRowCountChanged called");
//    });
//    dv.onPagingInfoChanged.subscribe(function(e,args) {
//        ok(false, "onPagingInfoChanged called");
//    });
//    dv.addItem({id:3,val:1337});
//    same(dv.getItems()[3], {id:3,val:1337}, "item updated");
//    assertConsistency(dv);
//});
//
//module("insertItem");
//
//test("must have id", function() {
//    var count = 0;
//    var dv = new Slick.Data.DataView();
//    dv.setItems([{id:0,val:0},{id:1,val:1},{id:2,val:2}]);
//    try {
//        dv.insertItem(0,{val:1337});
//        ok(false, "exception thrown");
//    }
//    catch (ex) {}
//});
//
//test("must have id (custom)", function() {
//    var count = 0;
//    var dv = new Slick.Data.DataView();
//    dv.setItems([{uid:0,val:0},{uid:1,val:1},{uid:2,val:2}], "uid");
//    try {
//        dv.insertItem(0,{id:3,val:1337});
//        ok(false, "exception thrown");
//    }
//    catch (ex) {}
//});
//
//test("insert at the beginning", function() {
//    var count = 0;
//    var dv = new Slick.Data.DataView();
//    dv.setItems([{id:0,val:0},{id:1,val:1},{id:2,val:2}]);
//    dv.onRowsChanged.subscribe(function(e,args) {
//        ok(true, "onRowsChanged called");
//        same(args, {rows:[0,1,2,3]}, "args");
//        count++;
//    });
//    dv.onRowCountChanged.subscribe(function(e,args) {
//        ok(true, "onRowCountChanged called");
//        equal(args.previous, 3, "previous arg");
//        equal(args.current, 4, "current arg");
//        count++;
//    });
//    dv.onPagingInfoChanged.subscribe(function(e,args) {
//        ok(true, "onPagingInfoChanged called");
//        equal(args.pageSize, 0, "pageSize arg");
//        equal(args.pageNum, 0, "pageNum arg");
//        equal(args.totalRows, 4, "totalRows arg");
//        count++;
//    });
//    dv.insertItem(0, {id:3,val:1337});
//    equal(count, 3, "events fired");
//    same(dv.getItem(0), {id:3,val:1337}, "item updated");
//    equal(dv.getItems().length, 4, "items updated");
//    equal(dv.getLength(), 4, "rows updated");
//    assertConsistency(dv);
//});
//
//test("insert in the middle", function() {
//    var count = 0;
//    var dv = new Slick.Data.DataView();
//    dv.setItems([{id:0,val:0},{id:1,val:1},{id:2,val:2}]);
//    dv.onRowsChanged.subscribe(function(e,args) {
//        ok(true, "onRowsChanged called");
//        same(args, {rows:[2,3]}, "args");
//        count++;
//    });
//    dv.onRowCountChanged.subscribe(function(e,args) {
//        ok(true, "onRowCountChanged called");
//        equal(args.previous, 3, "previous arg");
//        equal(args.current, 4, "current arg");
//        count++;
//    });
//    dv.onPagingInfoChanged.subscribe(function(e,args) {
//        ok(true, "onPagingInfoChanged called");
//        equal(args.pageSize, 0, "pageSize arg");
//        equal(args.pageNum, 0, "pageNum arg");
//        equal(args.totalRows, 4, "totalRows arg");
//        count++;
//    });
//    dv.insertItem(2,{id:3,val:1337});
//    equal(count, 3, "events fired");
//    same(dv.getItem(2), {id:3,val:1337}, "item updated");
//    equal(dv.getItems().length, 4, "items updated");
//    equal(dv.getLength(), 4, "rows updated");
//    assertConsistency(dv);
//});
//
//test("insert at the end", function() {
//    var count = 0;
//    var dv = new Slick.Data.DataView();
//    dv.setItems([{id:0,val:0},{id:1,val:1},{id:2,val:2}]);
//    dv.onRowsChanged.subscribe(function(e,args) {
//        ok(true, "onRowsChanged called");
//        same(args, {rows:[3]}, "args");
//        count++;
//    });
//    dv.onRowCountChanged.subscribe(function(e,args) {
//        ok(true, "onRowCountChanged called");
//        equal(args.previous, 3, "previous arg");
//        equal(args.current, 4, "current arg");
//        count++;
//    });
//    dv.onPagingInfoChanged.subscribe(function(e,args) {
//        ok(true, "onPagingInfoChanged called");
//        equal(args.pageSize, 0, "pageSize arg");
//        equal(args.pageNum, 0, "pageNum arg");
//        equal(args.totalRows, 4, "totalRows arg");
//        count++;
//    });
//    dv.insertItem(3,{id:3,val:1337});
//    equal(count, 3, "events fired");
//    same(dv.getItem(3), {id:3,val:1337}, "item updated");
//    equal(dv.getItems().length, 4, "items updated");
//    equal(dv.getLength(), 4, "rows updated");
//    assertConsistency(dv);
//});
//
//module("deleteItem");
//
//test("must have id", function() {
//    var count = 0;
//    var dv = new Slick.Data.DataView();
//    dv.setItems([{id:0,val:0},{id:1,val:1},{id:2,val:2}]);
//    try {
//        dv.deleteItem(-1);
//        ok(false, "exception thrown");
//    }
//    catch (ex) {}
//    try {
//        dv.deleteItem(undefined);
//        ok(false, "exception thrown");
//    }
//    catch (ex) {}
//    try {
//        dv.deleteItem(null);
//        ok(false, "exception thrown");
//    }
//    catch (ex) {}
//    try {
//        dv.deleteItem(3);
//        ok(false, "exception thrown");
//    }
//    catch (ex) {}
//});
//
//test("must have id (custom)", function() {
//    var count = 0;
//    var dv = new Slick.Data.DataView();
//    dv.setItems([{uid:0,id:-1,val:0},{uid:1,id:3,val:1},{uid:2,id:null,val:2}], "uid");
//    try {
//        dv.deleteItem(-1);
//        ok(false, "exception thrown");
//    }
//    catch (ex) {}
//    try {
//        dv.deleteItem(undefined);
//        ok(false, "exception thrown");
//    }
//    catch (ex) {}
//    try {
//        dv.deleteItem(null);
//        ok(false, "exception thrown");
//    }
//    catch (ex) {}
//    try {
//        dv.deleteItem(3);
//        ok(false, "exception thrown");
//    }
//    catch (ex) {}
//});
//
//test("delete at the beginning", function() {
//    var count = 0;
//    var dv = new Slick.Data.DataView();
//    dv.setItems([{id:05,val:0},{id:15,val:1},{id:25,val:2}]);
//    dv.onRowsChanged.subscribe(function(e,args) {
//        ok(true, "onRowsChanged called");
//        same(args, {rows:[0,1]}, "args");
//        count++;
//    });
//    dv.onRowCountChanged.subscribe(function(e,args) {
//        ok(true, "onRowCountChanged called");
//        equal(args.previous, 3, "previous arg");
//        equal(args.current, 2, "current arg");
//        count++;
//    });
//    dv.onPagingInfoChanged.subscribe(function(e,args) {
//        ok(true, "onPagingInfoChanged called");
//        equal(args.pageSize, 0, "pageSize arg");
//        equal(args.pageNum, 0, "pageNum arg");
//        equal(args.totalRows, 2, "totalRows arg");
//        count++;
//    });
//    dv.deleteItem(05);
//    equal(count, 3, "events fired");
//    equal(dv.getItems().length, 2, "items updated");
//    equal(dv.getLength(), 2, "rows updated");
//    assertConsistency(dv);
//});
//
//test("delete in the middle", function() {
//    var count = 0;
//    var dv = new Slick.Data.DataView();
//    dv.setItems([{id:05,val:0},{id:15,val:1},{id:25,val:2}]);
//    dv.onRowsChanged.subscribe(function(e,args) {
//        ok(true, "onRowsChanged called");
//        same(args, {rows:[1]}, "args");
//        count++;
//    });
//    dv.onRowCountChanged.subscribe(function(e,args) {
//        ok(true, "onRowCountChanged called");
//        equal(args.previous, 3, "previous arg");
//        equal(args.current, 2, "current arg");
//        count++;
//    });
//    dv.onPagingInfoChanged.subscribe(function(e,args) {
//        ok(true, "onPagingInfoChanged called");
//        equal(args.pageSize, 0, "pageSize arg");
//        equal(args.pageNum, 0, "pageNum arg");
//        equal(args.totalRows, 2, "totalRows arg");
//        count++;
//    });
//    dv.deleteItem(15);
//    equal(count, 3, "events fired");
//    equal(dv.getItems().length, 2, "items updated");
//    equal(dv.getLength(), 2, "rows updated");
//    assertConsistency(dv);
//});
//
//test("delete at the end", function() {
//    var count = 0;
//    var dv = new Slick.Data.DataView();
//    dv.setItems([{id:05,val:0},{id:15,val:1},{id:25,val:2}]);
//    dv.onRowsChanged.subscribe(function(e,args) {
//        ok(false, "onRowsChanged called");
//    });
//    dv.onRowCountChanged.subscribe(function(e,args) {
//        ok(true, "onRowCountChanged called");
//        equal(args.previous, 3, "previous arg");
//        equal(args.current, 2, "current arg");
//        count++;
//    });
//    dv.onPagingInfoChanged.subscribe(function(e,args) {
//        ok(true, "onPagingInfoChanged called");
//        equal(args.pageSize, 0, "pageSize arg");
//        equal(args.pageNum, 0, "pageNum arg");
//        equal(args.totalRows, 2, "totalRows arg");
//        count++;
//    });
//    dv.deleteItem(25);
//    equal(count, 2, "events fired");
//    equal(dv.getItems().length, 2, "items updated");
//    equal(dv.getLength(), 2, "rows updated");
//    assertConsistency(dv);
//});
//
//// TODO: paging
//// TODO: combination
//
//
//})(jQuery);
  });
}