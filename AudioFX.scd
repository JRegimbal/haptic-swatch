(
SynthDef(\whatever, {|bus = 0, freq = 440, mix = 0.5, atk = 3, set = 0, rel = 3, resonz=1.0, gain = 0.8|
	var env, sound, output;
	env = Slew.kr(set, atk, rel);
	sound = Saw.ar(freq, mix) + WhiteNoise.ar(1.0 - mix);
	output = Resonz.ar(env * sound, freq, resonz, gain * AmpCompA.kr(freq));
	Out.ar(bus, output);
}).add;

~synthDict = Dictionary();
~processRelease = {|index|
	if(~synthDict.includesKey(index),
		{
			~synthDict.at(index).set(\set, 0);
			~synthDict.removeAt(index);
		}
	);
};
~processCreate = {|index, freq, mix, atk, release, res, force|
	var set = 0;
	"Index: ".post;
	index.postln;
	~processRelease.(index);
	~synthDict.put(
		index,
		Synth.new(\whatever, [\mix, mix, \freq, freq, \rel, release, \atk, atk, \resonz, res, \set, set])
	);
};
~processTouch = {|index, freq, mix, atk, release, res, force|
	var set;
	"Index: ".post;
	index.postln;
	set = force.linlin(0, 4, 0, 1);
	atk = 1 / atk;
	release = 1 / release;
	set.postln;
	~synthDict.at(index).set(\mix, mix, \freq, freq, \rel, release, \atk, atk, \resonz, res, \set, set);
};
//)
//(
~osc1 = OSCFunc.new({|msg, time, addr, recvPort|
	var index = msg.at(1).asInteger;
	msg.postln;
	~processTouch.(index, msg.at(2).asFloat, msg.at(3).asFloat, msg.at(4).asFloat, msg.at(5).asFloat, msg.at(6).asFloat, msg.at(7).asFloat);
}, "/audio/touch");
~osc2 = OSCFunc.new({|msg, time, addr, recvPort|
	var index = msg.at(1).asInteger;
	msg.postln;
	~processCreate.(index, msg.at(2).asFloat, msg.at(3).asFloat, msg.at(4).asFloat, msg.at(5).asFloat, msg.at(6).asFloat, msg.at(7).asFloat);
}, "/audio/create");
)
(~osc1.free; ~osc2.free;)
OSCFunc.trace(true);
s.boot;
s.quit