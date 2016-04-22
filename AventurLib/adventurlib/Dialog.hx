package adventurlib;

import luxe.Entity;
import luxe.options.EntityOptions;
import luxe.tween.Actuate;
import luxe.Vector;

/*
typedef DialogOptions = {
	> EntityOptions,
	@:optional var words : Array<Word>;
}
*/

//TOOD: make this a real class
class Dialog extends Entity {
	public var curSentence (get,null) : Array<Word>;
	var sentences : Array<Array<Word>> = [];
	var sentenceIndex = 0;

	var dialogWidth = 650;
	var wordHeight = 50;
	var spaceWidth = 20;

	public var isAnimationInProgress = false;

	public override function new(options:EntityOptions) {
		super(options);
		sentences.push([]);
	}

	public function addWord(w:Word) {
		w.parent = this;
		w.height = wordHeight;
		w.pos = new Vector(0,0);

		var wordPos = new Vector(0, 0);
		if (curSentence.length > 0) {
			var prevWord = curSentence[curSentence.length-1];
			if (prevWord.pos.x + w.width > dialogWidth) {
				w.pos.y = prevWord.pos.y + (wordHeight + 20);
			}
			else {
				w.pos.y = prevWord.pos.y;
				w.pos.x = prevWord.pos.x + prevWord.width + spaceWidth;
			}
		}

		curSentence.push(w);
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
				var w = new Word({}).fromJson(j);
				addWord(w);
			}
			hideSentence(sentenceIndex);
			sentenceIndex++;
		}
		return this;
	}

}