// -*- mode: java -*-
/**
 * ARTIFICIAL FACE
 * No realheads allowed.
 * 
 * Love Lagerkvist, Malte Dahlberg — 221014
 */

import java.util.Map;
import processing.video.*;
import oscP5.*;
import netP5.*;

public class State {
	public Table table;

	public StringDict subtitles;
	public HashMap<String, Movie> videos;
	public boolean videoIsPlaying;

	public OscP5 oscP5;
	public NetAddress oscSource;
	public ArrayList<OscMessage> oscMessages;
}

State state;
String stopMessage = "/stop";

void setup() {
	size(800, 800);
	frameRate(30);
	pixelDensity(2);
	smooth(4);

	// Typography
	PFont font = loadFont("SVTUndertext-48.vlw");
	textFont(font);
	textAlign(CENTER, CENTER);

	// State
	state = new State();

	state.table = loadTable("data.csv", "header");
	assert(state.table.getRowCount() > 0);

	state.subtitles = new StringDict();
	state.videos = new HashMap<String, Movie>();
	// Perform wordWrapping and video loading in a prepass
	// NOTE: make sure all the video clips fit in memory
	for (TableRow row : state.table.rows()) {
		String key = row.getString("msg");

		int maxWidth = width - 100;
		String subtitle = wordWrap(row.getString("subtitle"), maxWidth);
		state.subtitles.set(key, subtitle);

		String path = row.getString("video");
		state.videos.put(key, new Movie(this, path));
	}
	state.videoIsPlaying = false;

	state.oscP5       = new OscP5(this, 12000);
	state.oscSource   = new NetAddress("127.0.0.1", 12000); // Listens on localhost:12000
	state.oscMessages = new ArrayList<OscMessage>();
	state.oscMessages.add(new OscMessage("/test/first")); // XXX: test
}

boolean startsWithSpace(String s) {
	return s.length() > 0 && s.charAt(0) == ' ';
}

String skipWhitespace(String s) {
	return (startsWithSpace(s)) ? s.substring(1, s.length()) : s;
}

/* Based off: https://shiffman.net/blog/p5/programming/teaching_/2006/10/17/word-wrap-in-processing/ */
String wordWrap(String s, int maxWidth) {
	if (s == null || s.length() == 0) return "";

	// For whatever reason, parsing the table seems to turns \n into something != to \n...
	// So, we sub the dollar sign in order to manually controll wrapping when that is required.
	if (s.contains("$")) return s.replaceAll("\\$", "\n");

	String wrapped = "";
	float width = 0;
	int i = 0;
	int lastSpace = 0;

	while (i < s.length()) {
		char c = s.charAt(i);
		width += textWidth(c);
		if (c == ' ') lastSpace = i;

		if (!(width > maxWidth)) { i++; continue; }

		String sub = s.substring(0, lastSpace);
		sub = skipWhitespace(sub);

		wrapped += (wrapped.length() == 0) ? sub : '\n' + sub;
		s = s.substring(lastSpace, s.length());
		i = 0;
		width = 0;
	}

	// The last line
	wrapped += '\n' + skipWhitespace(s);
	return wrapped;
}

// https://sojamo.de/libraries/oscP5/reference/index.html
void oscEvent(OscMessage m) {
	println("### new OscMsg: " + m.toString());
	state.oscMessages.add(m);
}

void drawSubtitles(String subtitle) {
	fill(254, 254, 71);
	text(subtitle, width/2, height/2);
}

void playVideo(Movie video) {
	if (!state.videoIsPlaying) {
		video.loop();
		state.videoIsPlaying = true;
	}

	if (video != null) {
		image(video, 0, 0); // TODO: Pos
	}
}

void movieEvent(Movie m) {
	m.read();
}

void stopVideo() {
	Movie video = getCurrentVideo();
	if (video.available()) {
		video.stop();
		video = null;
	}
}

// NOTE: I assume that we use the `addrPattern` part of the OscMessage
//       as our key? If not, change the method call here ↓
String lastOscMessage() {
	int last = state.oscMessages.size()-1;
	return state.oscMessages.get(last).addrPattern();
}

String getCurrentSubtitle() {
	return state.subtitles.get(lastOscMessage());
}

Movie getCurrentVideo() {
	return state.videos.get(lastOscMessage());
}

void draw() {
	if (lastOscMessage() == stopMessage) {
		stopVideo();
		background(0);
	} else {
		playVideo(getCurrentVideo());
		drawSubtitles(getCurrentSubtitle());
	}
}
