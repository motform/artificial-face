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
	public String playingVideo;

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
	println(state.subtitles);
	state.playingVideo = null;

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

void addTestOscMessage(String msg) {
	state.oscMessages.add(new OscMessage(msg));
}

void keyPressed() {
	switch(key) {
	case 'a': addTestOscMessage("/test/first");  break;
	case 'r': addTestOscMessage("/test/second"); break;
	case 's': addTestOscMessage(stopMessage);    break;
	}	
}

void drawSubtitles() {
	String subtitle = state.subtitles.get(lastOscMessage());
	if (subtitle == null) {
		println("Error: unable to draw subtitle", subtitle, lastOscMessage());
		return;
	}
		
	fill(254, 254, 71);
	text(subtitle, width/2, height/2);
}

void playVideo() {
	Movie video;
	String lastMessage = lastOscMessage();

	if (state.playingVideo == null || !state.playingVideo.equals(lastMessage)) {
		stopVideo(); // Make sure to stop the playing of the old video

		video = state.videos.get(lastMessage);
		println("starting new video", lastMessage);
		if (video == null) { // This is only reached when a video has been incorrectly loaded
			println("Error: unable to play video", lastMessage);
			assert(false); // We would rather not have errors in our dataset than to gracefully handle them
		}

		video.loop();
		state.playingVideo = lastMessage;
	} else {
		video = state.videos.get(lastMessage);
	}

	// TODO: Position the video when we have the final frame size (probably 1920x1080?)
	image(video, 0, 0); 
}


void movieEvent(Movie m) {
	// println("drawing frame from", state.playingVideo);
	// always tries to draw frame from /test/first? somthing with the processing video implementation???
	// The `this` paramater in the constructor is a bit... worrying
	m.read();
}

void stopVideo() {
	if (state.playingVideo == null) return;

	Movie video = state.videos.get(state.playingVideo);
	if (video != null) {
		println("Stopping video", state.playingVideo, video);
		video.stop();
	}

	state.playingVideo = null;
}

// NOTE: I assume that we use the `addrPattern` part of the OscMessage
//       as our key? If not, change the method call here ↓
String lastOscMessage() {
	int last = state.oscMessages.size()-1;
	return state.oscMessages.get(last).addrPattern();
}

void draw() {
	if (lastOscMessage().equals(stopMessage)) {
		stopVideo();
		background(0);
	} else {
		background(0);
		playVideo();
		drawSubtitles();
	}
}

/*
  - två olika saker
  - syntetiska fältinspelningar
  - Svart bakgrund
  - Kören
  - Filmisk bakgrund
*/
