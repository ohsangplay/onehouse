import 'package:flutter_test/flutter_test.dart';
import 'package:memo/widgets/memo_links.dart';

void main() {
  List<String> links(String text) => findLinks(text).map((u) => u.toString()).toList();

  test('http/https/www 링크를 찾는다', () {
    expect(links('장보기 https://coupang.com/abc?x=1 확인'), ['https://coupang.com/abc?x=1']);
    expect(links('www.naver.com 참고'), ['https://www.naver.com']);
    expect(links('HTTP://Example.com/A').single.toLowerCase(), 'http://example.com/a');
  });

  test('문장부호·한글 앞에서 끊는다', () {
    expect(links('여기(https://a.com/b).'), ['https://a.com/b']);
    expect(links('https://a.com에서 사기'), ['https://a.com']);
    expect(links('주소: https://a.com/x, https://b.org!'), ['https://a.com/x', 'https://b.org']);
  });

  test('중복은 한 번만, 링크 아닌 건 무시', () {
    expect(links('https://a.com https://a.com'), ['https://a.com']);
    expect(links('http://localhost 그리고 https:// 그냥'), isEmpty);
    expect(links('메모 내용만 있음'), isEmpty);
  });

  test('보여줄 이름', () {
    expect(linkLabel(Uri.parse('https://www.naver.com/')), 'naver.com');
    expect(linkLabel(Uri.parse('https://a.com/very/long/path/that/goes/on/and/on')).length, lessThanOrEqualTo(32));
  });

  test('누른 위치의 링크 찾기', () {
    const text = '방 https://yahchoo.ohsangplay.com?room=ve6c 들어와';
    final start = text.indexOf('https');
    final end = text.indexOf(' 들어와');
    expect(linkAt(text, start).toString(), 'https://yahchoo.ohsangplay.com?room=ve6c');
    expect(linkAt(text, start + 10), isNotNull);
    expect(linkAt(text, end), isNotNull); // 링크 바로 뒤 (아이폰은 단어 끝으로 커서가 감)
    expect(linkAt(text, 0), isNull);
    expect(linkAt(text, text.length), isNull);
  });

  test('링크 위치는 끝 문장부호 제외', () {
    final r = linkRanges('여기(https://a.com/b).').single;
    expect('여기(https://a.com/b).'.substring(r.start, r.end), 'https://a.com/b');
  });
}
