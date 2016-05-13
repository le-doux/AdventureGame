package adventurlib;

import luxe.Visual;
import luxe.options.VisualOptions;
import luxe.tween.Actuate;
import luxe.Vector;

typedef DialogOptions = {
	> VisualOptions,
	@:optional var dialogWidth : Float;
	@:optional var wordHeight : Float;
	@:optional var spaceWidth : Float;
}

//TOOD: make this a real class
class Dialog extends Visual {
	public var curSentence (get,null) : Array<Word>;
	var sentences : Array<Array<Word>> = [];
	var sentenceIndex = 0;

	var dialogWidth : Float = 650;
	var wordHeight : Float = 50;
	var spaceWidth : Float = 20;

	public var isAnimationInProgress = false;

	private var _batcher : phoenix.Batcher;

	public override function new(options:DialogOptions) {
		options.no_geometry = true;
		super(options);
		_batcher = options.batcher;

		if (options.dialogWidth != null) dialogWidth = options.dialogWidth;
		if (options.wordHeight != null) wordHeight = options.wordHeight;
		if (options.spaceWidth != null) spaceWidth = options.spaceWidth;

		sentences.push([]);
	}

	public function addWord(w:Word) {
		w.parent = this;
		w.height = wordHeight;
		w.pos = insertPoint(curSentence.length-1, w.width);
		curSentence.push(w);
	}

	public function insertPoint(i : Int, ?wordWidth : Float) {
		if (wordWidth == null) wordWidth = 0;

		var pos = new Vector(0, wordHeight);
		trace(curSentence);
		if (curSentence.length > i && i >= 0) {
			var prevWord = curSentence[i];
			if (prevWord.pos.x + wordWidth > dialogWidth) {
				pos.y = prevWord.pos.y + (wordHeight + 20);
			}
			else {
				pos.y = prevWord.pos.y;
				pos.x = prevWord.pos.x + prevWord.width + spaceWidth;
			}
		}
		return pos;
	}

	public function insertWord(w:Word, i:Int) {

		var wordList = [];
		var j = i+1;
		while (j < curSentence.length) {
			var w = curSentence[j];
			wordList.push(w);
			j++;
		}

		for (w in wordList) {
			curSentence.remove(w);
		}

		w.parent = this;
		w.height = wordHeight;
		w.pos = insertPoint(i, w.width);
		curSentence.push(w);

		for (w in wordList) {
			addWord(w);
		}
	}

	public function deleteWord(i : Int) { //from end of sentence
		var w = curSentence[i];
		w.destroy(true);
		curSentence.remove(w);

		var wordList = [];
		while (i < curSentence.length) {
			var w = curSentence[i];
			wordList.push(w);
			i++;
		}

		for (w in wordList) {
			curSentence.remove(w);
		}

		for (w in wordList) {
			addWord(w);
		}

	}

	//seems dumb
	public function returnToEditing() {
		sentenceIndex = sentences.length - 1;
		showSentence(sentenceIndex);
	}

	public function beginDialog() {
		var i = 0;
		for (s in sentences) {
			hideSentence(i);
			i++;
		}
		sentenceIndex = -1;
	}

	public function showNext() : Bool {
		if (sentenceIndex >= 0) hideSentence(sentenceIndex);
		sentenceIndex++;
		if (sentenceIndex < sentences.length) {
			showSentence(sentenceIndex);
			animateSentence(5);
		}
		return sentenceIndex < sentences.length;
	}

	//includes some assumptions for the editor
	public function newSentence() {
		hideSentence(sentenceIndex);
		sentences.push([]);
		sentenceIndex++;
	}

	function showSentence(i:Int) {
		for (w in sentences[i]) {
			w.visible = true;
		}
	}

	function hideSentence(i:Int) {
		for (w in sentences[i]) {
			w.visible = false;
		}
	}

	public function animateSentence(t:Float) {
		if (!isAnimationInProgress) {
			isAnimationInProgress = true;
			var animateSentenceControl = {
				delta : 0.0
			};
			Actuate.tween(animateSentenceControl, t, {delta:1.0*curSentence.length})
				.onUpdate(function() {
					var curDelta = animateSentenceControl.delta;
					for (word in curSentence) {
						word.drawIncomplete(curDelta);
						curDelta -= 1.0;
					}
				}).onComplete(function() {
						isAnimationInProgress = false;
					});
		}
	}

	public function get_curSentence() : Array<Word> {
		trace(sentences.length);
		trace(sentenceIndex);
		return sentences[sentenceIndex];
	}

	public function toJson() {
		var jsonSentences : Array<Array<Dynamic>> = [];
		for (s in sentences) {
			var jsonS = [];
			for (w in s) {
				jsonS.push(w.toJson());
			}
			jsonSentences.push(jsonS);
		}
		return {
			sentences : jsonSentences
		};
	}

	public function fromJson(json) : Dialog {
		sentences = []; //overwrite old sentences (but kind of assumes there isn't anything there...)
		sentenceIndex = 0;
		for (jArr in cast(json.sentences, Array<Dynamic>)) {
			sentences.push([]);
			for (j in cast(jArr, Array<Dynamic>)) {
				var w : Word;
				if (_batcher != null) {
					w = new Word({batcher:_batcher}).fromJson(j);
				}
				else {
					w = new Word({}).fromJson(j);
				}
				addWord(w);
			}
			hideSentence(sentenceIndex);
			sentenceIndex++;
		}
		sentenceIndex--;
		showSentence(sentenceIndex);
		return this;
	}

	public function prevSentence() : Bool {
		hideSentence(sentenceIndex);
		sentenceIndex--;
		if (sentenceIndex >= 0) {
			showSentence(sentenceIndex);
			return true;
		}
		else {
			sentenceIndex = 0;
			showSentence(sentenceIndex);
			return false;
		}
	}

	public function nextSentence() : Bool {
		hideSentence(sentenceIndex);
		sentenceIndex++;
		if (sentenceIndex < sentences.length) {
			showSentence(sentenceIndex);
			return true;
		}
		else {
			sentenceIndex = sentences.length - 1;
			showSentence(sentenceIndex);
			return false;
		}
	}

}