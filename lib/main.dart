import 'dart:convert';
import 'dart:io';

import 'package:bloc/bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'dart:developer' as devtools show log;

extension Log on Object{
  void log() => devtools.log(toString());
}

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: BlocProvider(
        create: ((_) => PersonBloc()),
        child: const MyHomePage(),
      ),
    );
  }
}

@immutable
abstract class LoadAction {
  const LoadAction();
}

enum PersonUrl { person, post }

extension UrlString on PersonUrl {
  String get urlString {
    switch (this) {
      case PersonUrl.person:
        return 'https://jsonplaceholder.typicode.com/users';
      case PersonUrl.post:
        return 'https://jsonplaceholder.typicode.com/posts';
    }
  }
}

@immutable
class PersonLoadActions implements LoadAction {
  final PersonUrl url;
  const PersonLoadActions({required this.url}) : super();
}

class Person {
  final String name;
  final String email;

  const Person({
    required this.name,
    required this.email,
  });

  Person.fromJson(Map<String, dynamic> json)
      : name = json['name'] as String,
        email = json['email'] as String;
}

Future<Iterable<Person>> getPersons(String url) => HttpClient()
    .getUrl(Uri.parse(url))
    .then((req) => req.close())
    .then((resp) => resp.transform(utf8.decoder).join())
    .then((str) => json.decode(str) as List<dynamic>)
    .then((list) => list.map((e) => Person.fromJson(e)));

@immutable
class FetchResult {
  final Iterable<Person> persons;
  final bool isRetriveFromCache;

  const FetchResult({
    required this.persons,
    required this.isRetriveFromCache,
  });

  @override
  String toString() =>
      'FetchResult (isRetriveFromCache: $isRetriveFromCache, persons: $persons';
}

class PersonBloc extends Bloc<LoadAction, FetchResult?> {
  final Map<PersonUrl, Iterable<Person>> _cache = {};
  PersonBloc() : super(null) {
    on<PersonLoadActions>((event, emit) async {
      final url = event.url;
      if (_cache.containsKey(url)) {
        // we have the value in cache
        final cachePersons = _cache[url]!;
        final result = FetchResult(
          persons: cachePersons,
          isRetriveFromCache: true,
        );
        emit(result);
      } else {
        final persons = await getPersons(url.urlString);
        _cache[url] = persons;
        final result = FetchResult(
          persons: persons,
          isRetriveFromCache: false,
        );
        emit(result);
      }
    });
  }
}

extension Subscript<T> on Iterable<T> {
  T? operator [](int index) => length > index ? elementAt(index) : null;
}

class MyHomePage extends StatelessWidget {
  const MyHomePage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Home Page'),
      ),
      body: Column(
        children: [
          Row(
            children: [
              TextButton(
                onPressed: () {
                  context.read<PersonBloc>().add(
                        const PersonLoadActions(
                          url: PersonUrl.person,
                        ),
                      );
                },
                child: const Text('Load Json #1'),
              ),
              TextButton(
                onPressed: () {
                  context.read<PersonBloc>().add(
                        const PersonLoadActions(
                          url: PersonUrl.post,
                        ),
                      );
                },
                child: const Text('Load Json #2'),
              ),
            ],
          ),
          BlocBuilder<PersonBloc, FetchResult?>(
              buildWhen: (previousResult, currentResult) {
            return previousResult?.persons != currentResult?.persons;
          }, builder: (context, fetchResult) {
                fetchResult?.log();
                final  persons = fetchResult?.persons;
                if(persons == null){
                  return const SizedBox();
                }
                return Expanded(
                  child:
                    ListView.builder(
                      itemCount: persons.length,
                        itemBuilder: (context, index){
                        final person = persons[index]!;
                        return ListTile(title: Text(person.name),);
                    }),
                );
          }),
        ],
      ),
    );
  }
}
