(
SynthDef(\whatever, {|bus = 0, freq = 440, mix = 0.5, atk = 0.1, rel = 2, gate = 1, resonz=1.0, gain = 0.8|
	var env, sound, output;
	env = EnvGen.ar(
		// Env.asr(atk, releaseTime: rel),
		Env.adsr(atk, 0.05, 0.5, rel),
		gate,
		doneAction: Done.freeSelf
	);
	sound = Saw.ar(freq, mix) + WhiteNoise.ar(1.0 - mix);
	output = Resonz.ar(env * sound, freq, resonz, gain);
	Out.ar(bus, output);
}).add;
)

(
{
a = Synth.new(\whatever, [\mix, 0.6, \freq, 220, \rel, 5]);
0.3.wait;
a.set(\gate, 0);
}.fork();
)
(
a.set(\gate, 0);
)
(
~synthDict = Dictionary();
~processRelease = {|index|
	if(~synthDict.includesKey(index),
		{
			~synthDict.at(index).set(\gate, 0);
			~synthDict.removeAt(index);
		}
	);
};
~processTouch = {|index, freq, mix, atk, release, res|
	"Index: ".post;
	index.postln;
	~processRelease.(index);
	~synthDict.put(
		index,
		Synth.new(\whatever, [\mix, mix, \freq, freq, \rel, release, \atk, atk, \resonz, res])
	);
};
)
(
~osc1 = OSCFunc.new({|msg, time, addr, recvPort|
	var index = msg.at(1).asInteger;
	msg.postln;
	~processTouch.(index, msg.at(2).asFloat, msg.at(3).asFloat, msg.at(4).asFloat, msg.at(5).asFloat, msg.at(6).asFloat);
}, "/audio/touch");
~osc2 = OSCFunc.new({|msg, time, addr, recvPort|
	var index = msg.at(1).asInteger;
	msg.postln;
	~processRelease.(index);
}, "/audio/release");
)
OSCdef.freeAll;
(~osc1.free; ~osc2.free;)
NetAddr.langPort;
OSCFunc.trace(true);

(
Synth.new(\whatever,
	[