// -*- mode: java-mode -*-
/**
 * ARTIFICIAL FACE
 * No realheads allowed.
 * 
 * Love Lagerkvist, Malte Dahlberg — 221014
 */
 
import oscP5.*;
import netP5.*;
  
OscP5 oscP5;
NetAddress oscSource;

StringDict words;
String currentWord = "";

void setup() {
	size(800, 800);
	frameRate(60);
	pixelDensity(2);

	// Typography
	PFont font;
	// font = loadFont("SVTUndertext-72.vlw");
	font = loadFont("SVTUndertext-48.vlw");
	textFont(font);
	textAlign(CENTER, CENTER);

	words = loadWords("example.tsv");
	currentWord = words.get("test"); // XXX

	// TODO start oscP5, listening for incoming messages at port 12000 
	oscP5 = new OscP5(this, 12000);
	oscSource = new NetAddress("127.0.0.1", 12000);
}

StringDict loadWords(String path) {
	StringDict words = new StringDict();
	Table tsv = loadTable(path, "header, tsv");
	assert(tsv.getRowCount() > 0);

	for (TableRow row : tsv.rows())
		words.set(row.getString("msg"), row.getString("str"));

	return words;
}

boolean startsWithSpace(String s) {
	return s.length() > 0 && s.charAt(0) == ' ';
}

String skipWhitespace(String s) {
	return (startsWithSpace(s)) ? s.substring(1, s.length()) : s;
}

/* Based off: https://shiffman.net/blog/p5/programming/teaching_/2006/10/17/word-wrap-in-processing/ */
String wordWrap(String str, int maxWidth) {
	String wrapped = "";

	float width = 0;
	int i = 0;
	int lastSpace = 0;

	while (i < str.length()) {
		char c = str.charAt(i);
		width += textWidth(c);
		if (c == ' ') lastSpace = i;

		if (!(width > maxWidth)) { i++; continue; }

		String sub = str.substring(0, lastSpace);
		sub = skipWhitespace(sub);

		wrapped += (wrapped.length() == 0) ? sub : '\n' + sub;
		str = str.substring(lastSpace, str.length());
		i = 0;
		width = 0;
	}

	// The last line
	wrapped += '\n' + skipWhitespace(str);
	return wrapped;
}

void drawSubtitles(String subtitle) {
	int maxWidth = width - 100;
	text(wordWrap(subtitle, maxWidth), // str
		 width/2,   // X
		 height/2); // y
}

/* TODO Incoming osc message are forwarded to the oscEvent method. */
void oscEvent(OscMessage m) {
	print  ("### received an osc message.");
	print  (" addrpattern: " + m.addrPattern());
	println(" typetag: " + m.typetag());
}

void draw() {
	background(0);  
	drawSubtitles(currentWord);
}
