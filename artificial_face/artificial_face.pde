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
	/* The video tracking is a bit more complicated than the rest.
	   First, we keep a dict of msg->path. This is required as several msg can share the same path.
	   Then, we have a map of path->Movie, where the Movie is reference to a buffered P5 object.
	   This decoupling makes it possible and easy to keep playing the same object when swapping msg.
	   Finally, we need to know what is currently playing in order to stop it when switching video.
	   Hence, the `playingVideoPath` property.
	   — LLA 221012
	*/
	public StringDict videoPaths;
	public HashMap<String, Movie> videos;
	public String playingVideoPath;

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

	// Perform word wrapping and video buffering in a prepass
	// NOTE: Make sure all the video clips fit in memory
	state.subtitles  = new StringDict();
	state.videoPaths = new StringDict();
	state.videos     = new HashMap<String, Movie>();
	for (TableRow row : state.table.rows()) {
		String key = row.getString("msg");

		int maxWidth = width - 100;
		String subtitle = wordWrap(row.getString("subtitle"), maxWidth);
		state.subtitles.set(key, subtitle);

		String videoPath = row.getString("video");
		state.videoPaths.set(key, videoPath);
		if (!state.videos.containsKey(videoPath)) {
			Movie video = new Movie(this, videoPath);
			state.videos.put(videoPath, video);
		}
	}
	state.playingVideoPath = null;

	state.oscP5       = new OscP5(this, 12000);
	state.oscSource   = new NetAddress("127.0.0.1", 12000); // Listens on localhost:12000
	state.oscMessages = new ArrayList<OscMessage>();
	state.oscMessages.add(new OscMessage(stopMessage)); // Always start with the stop 
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
	case 'a': addTestOscMessage("/test/one");  break;
	case 'r': addTestOscMessage("/test/two"); break;
	case 't': addTestOscMessage("/test/three"); break;
	case 'd': addTestOscMessage("/test/four"); break;
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

// TODO: update this to support the new video state management
void playVideo() {
	Movie video;
	String lastMessage = lastOscMessage();
	String videoPath = state.videoPaths.get(lastMessage);

	if (state.playingVideoPath == null || !state.playingVideoPath.equals(videoPath)) {
		stopVideo(); // Make sure to stop the playing of the old video

		state.playingVideoPath = videoPath;
		video = state.videos.get(state.playingVideoPath);
		println("starting new video", state.playingVideoPath);
		if (video == null) { // This is only reached when a video has been incorrectly loaded
			println("Error: unable to play video", videoPath, "from message", lastMessage);
			assert(false); // We would rather not have errors in our dataset than to gracefully handle them
		} else {
		video.loop();
		}
	} else {
		video = state.videos.get(state.playingVideoPath);
	}

	// TODO: Position the video when we have the final frame size (probably 1920x1080?)
	image(video, 0, 0); 
}


void movieEvent(Movie m) {
	// println("drawing frame from", state.playingVideoPath);
	// always tries to draw frame from /test/first? somthing with the processing video implementation???
	// The `this` paramater in the constructor is a bit... worrying
	m.read();
}

void stopVideo() {
	if (state.playingVideoPath == null) return;

	String videoPath = state.videoPaths.get(state.playingVideoPath);
	Movie video = state.videos.get(videoPath);
	if (video != null) {
		println("Stopping video", videoPath, state.playingVideoPath, video);
		video.stop();
	}

	state.playingVideoPath = null;
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
