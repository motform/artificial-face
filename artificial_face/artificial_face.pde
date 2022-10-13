// -*- mode: java -*-
/**
 * ARTIFICIAL FACE
 * No realheads allowed.
 * 
 * Love Lagerkvist, Malte Dahlberg — 221014
 */

import java.util.Map;
import java.util.concurrent.*;
import processing.video.*;
import oscP5.*;
import netP5.*;

// Settings
boolean DEBUG = true;
boolean SQUARE_VIDEO = false;

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
	public ArrayBlockingQueue<OscMessage> queuedOscMessages;
	public OscMessage oscMessage;
}

State state;
String stopMessage = "/stop";

void setup() {
	fullScreen(2);
	// size(1920, 1080);
	frameRate(30);

	// Typography
	PFont font = loadFont("SVTUndertext-72.vlw");
	textFont(font);
	textAlign(CENTER, BOTTOM);

	// State
	state = new State();

	state.table = loadTable("data.csv", "header");
	if (DEBUG) assert(state.table.getRowCount() > 0);

	// Perform word wrapping and video buffering in a prepass
	// NOTE: Make sure all the video clips fit in memory
	state.subtitles  = new StringDict();
	state.videoPaths = new StringDict();
	state.videos     = new HashMap<String, Movie>();
	for (TableRow row : state.table.rows()) {
		String key = row.getString("msg");

		int maxWidth = width - 200;
		String subtitle = wordWrap(row.getString("subtitle"), maxWidth);
		state.subtitles.set(key, subtitle);

		String videoPath = row.getString("video");
		state.videoPaths.set(key, videoPath);
		if (!state.videos.containsKey(videoPath)) {
			Movie video = new Movie(this, videoPath);
			state.videos.put(videoPath, video);
		}
	}
	state.playingVideoPath = "blank.mp4";

	int oscPort = 12000;
	state.oscP5             = new OscP5(this, oscPort);
	state.oscSource         = new NetAddress("127.0.0.1", oscPort);
	state.queuedOscMessages = new ArrayBlockingQueue<OscMessage>(10);

	state.oscMessage = new OscMessage(stopMessage); // Always start with the stop 
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
	state.queuedOscMessages.add(m);
}

void addTestOscMessage(String msg) {
	state.queuedOscMessages.add(new OscMessage(msg));
}

void keyPressed() {
	switch(key) {
	case 'a': addTestOscMessage("/01/01/00");		break;
	case 'r': addTestOscMessage("/01/01/01");		break;
	case 't': addTestOscMessage("/02/01/01");		break;
	case 'd': addTestOscMessage("/02/01/00");		break;
	case 'h': addTestOscMessage("/03/01/00");		break;
	case 'b': addTestOscMessage("/bongo/tvman");	break;
	case 's': addTestOscMessage(stopMessage);		break;
	}	
}

void strokeText(String s, int x, int y) {
	fill(0);
	text(s, x-1, y);
	text(s, x, y-1);
	text(s, x+1, y);
	text(s, x, y+1);
	fill(254, 254, 71);
	text(s, x, y);
}

void drawSubtitles(String lastMessage) {
	String subtitle = state.subtitles.get(lastMessage);
	if (subtitle == null) {
		println("Error: unable to draw subtitle", subtitle, lastMessage);
		return;
	}
		
	int marginBottom = 100;
	strokeText(subtitle, width/2, height-marginBottom);
}

void playVideo(String lastMessage) {
	Movie video;
	String videoPath = state.videoPaths.get(lastMessage);

	if (state.playingVideoPath == null || !state.playingVideoPath.equals(videoPath)) {
		stopVideo(state.playingVideoPath); // Make sure to stop the playing of the old video

		state.playingVideoPath = videoPath;
		video = state.videos.get(state.playingVideoPath);

		if (video == null) { // This is only reached when a video has been incorrectly loaded
			println("Error: unable to play video", videoPath, "from message", lastMessage);
			if (DEBUG) assert(false); // We would rather not have errors in our dataset than to gracefully handle them
			return;
		} else {
			video.loop();
		}

	} else {
		video = state.videos.get(state.playingVideoPath);
	}

	if (SQUARE_VIDEO) {
		pushMatrix();
		{
			// TODO: Differenciate small and large images
			//       We can encode this data in the csv and keep it around,
			//       associated with the videoPath
			translate(width/2, height/2-100);
			imageMode(CENTER);
			image(video, 0, 0, height/2, height/2);
		}
		popMatrix();
	} else {
		image(video, 0, 0);
	}
}


void movieEvent(Movie m) {
	// println("drawing frame from", state.playingVideoPath);
	m.read();
}

void stopVideo(String videoPlayingPath) {
	if (videoPlayingPath == null) {
		println("Error: Trying to stop video videoPlayingPath that is null.");
		return;
	}

	Movie video = state.videos.get(videoPlayingPath);
	if (video != null) {
		println("Stopping video", videoPlayingPath, video);
		video.stop();
	}
}

void handleOscMessageQueue() {
	if (state.queuedOscMessages.peek() != null) {
		OscMessage message = state.queuedOscMessages.poll();
		String msg = message.addrPattern();
		if (state.subtitles.hasKey(msg)) state.oscMessage = message;
	}
}
	
void draw() {
	handleOscMessageQueue();
	String lastMessage = state.oscMessage.addrPattern();

	background(0);
	playVideo(lastMessage);
	drawSubtitles(lastMessage);
}
