// 日本語の世界 — speech input for speaking practice (MIT).
//
// A Godot Android plugin (v2) around android.speech.SpeechRecognizer. GDScript reaches it as the
// engine singleton "SpeechInput" (see game/scripts/core/speech_input.gd). Recognition prefers
// the on-device engine, so it works offline once the phone's Japanese speech pack is installed.
// tools/setup_android_build.py copies this file into the Gradle build template and registers it
// in the manifest.
package io.github.tamanegininja25.speech;

import android.app.Activity;
import android.content.Intent;
import android.os.Bundle;
import android.speech.RecognitionListener;
import android.speech.RecognizerIntent;
import android.speech.SpeechRecognizer;

import androidx.annotation.NonNull;

import org.godotengine.godot.Godot;
import org.godotengine.godot.plugin.GodotPlugin;
import org.godotengine.godot.plugin.SignalInfo;
import org.godotengine.godot.plugin.UsedByGodot;

import java.util.ArrayList;
import java.util.HashSet;
import java.util.Set;

public class SpeechInputPlugin extends GodotPlugin {
    private SpeechRecognizer recognizer;

    public SpeechInputPlugin(Godot godot) {
        super(godot);
    }

    @NonNull
    @Override
    public String getPluginName() {
        return "SpeechInput";
    }

    @NonNull
    @Override
    public Set<SignalInfo> getPluginSignals() {
        Set<SignalInfo> signals = new HashSet<>();
        // Best transcript, then every alternative joined with "\n" (best first).
        signals.add(new SignalInfo("speech_result", String.class, String.class));
        signals.add(new SignalInfo("speech_partial", String.class));
        // android.speech.SpeechRecognizer.ERROR_* code.
        signals.add(new SignalInfo("speech_error", Integer.class));
        signals.add(new SignalInfo("speech_ready"));
        signals.add(new SignalInfo("speech_end"));
        return signals;
    }

    @UsedByGodot
    public boolean isAvailable() {
        Activity activity = getActivity();
        return activity != null && SpeechRecognizer.isRecognitionAvailable(activity);
    }

    /** Listen once in [language] (BCP 47, e.g. "ja-JP"); results arrive as signals. */
    @UsedByGodot
    public void start(final String language) {
        final Activity activity = getActivity();
        if (activity == null) {
            emitSignal("speech_error", SpeechRecognizer.ERROR_CLIENT);
            return;
        }
        runOnUiThread(() -> {
            destroyRecognizer();
            recognizer = SpeechRecognizer.createSpeechRecognizer(activity);
            recognizer.setRecognitionListener(new Listener());
            Intent intent = new Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH);
            intent.putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM);
            intent.putExtra(RecognizerIntent.EXTRA_LANGUAGE, language);
            intent.putExtra(RecognizerIntent.EXTRA_LANGUAGE_PREFERENCE, language);
            intent.putExtra(RecognizerIntent.EXTRA_PREFER_OFFLINE, true);
            intent.putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true);
            intent.putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 5);
            recognizer.startListening(intent);
        });
    }

    /** Stop listening and deliver what was heard so far. */
    @UsedByGodot
    public void stop() {
        runOnUiThread(() -> {
            if (recognizer != null) {
                recognizer.stopListening();
            }
        });
    }

    /** Stop listening and discard the result. */
    @UsedByGodot
    public void cancel() {
        runOnUiThread(this::destroyRecognizer);
    }

    @Override
    public void onMainDestroy() {
        destroyRecognizer();
        super.onMainDestroy();
    }

    private void destroyRecognizer() {
        if (recognizer != null) {
            recognizer.cancel();
            recognizer.destroy();
            recognizer = null;
        }
    }

    private static String join(ArrayList<String> items) {
        StringBuilder sb = new StringBuilder();
        for (String item : items) {
            if (sb.length() > 0) {
                sb.append('\n');
            }
            sb.append(item);
        }
        return sb.toString();
    }

    private class Listener implements RecognitionListener {
        @Override
        public void onReadyForSpeech(Bundle params) {
            emitSignal("speech_ready");
        }

        @Override
        public void onBeginningOfSpeech() {
        }

        @Override
        public void onRmsChanged(float rmsdB) {
        }

        @Override
        public void onBufferReceived(byte[] buffer) {
        }

        @Override
        public void onEndOfSpeech() {
            emitSignal("speech_end");
        }

        @Override
        public void onError(int error) {
            emitSignal("speech_error", error);
        }

        @Override
        public void onResults(Bundle results) {
            ArrayList<String> heard = results.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION);
            if (heard == null || heard.isEmpty()) {
                emitSignal("speech_error", SpeechRecognizer.ERROR_NO_MATCH);
                return;
            }
            emitSignal("speech_result", heard.get(0), join(heard));
        }

        @Override
        public void onPartialResults(Bundle partialResults) {
            ArrayList<String> heard = partialResults.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION);
            if (heard != null && !heard.isEmpty()) {
                emitSignal("speech_partial", heard.get(0));
            }
        }

        @Override
        public void onEvent(int eventType, Bundle params) {
        }
    }
}
