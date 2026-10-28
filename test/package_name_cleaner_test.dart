import 'package:flutter_test/flutter_test.dart';
import 'package:ai_routine_assistant/services/app_label_helper.dart';

void main() {
  group('AppLabelHelper.cleanPackageName Tests', () {
    test('Cleans known seeded apps into proper brand names', () {
      expect(AppLabelHelper.cleanPackageName('com.android.chrome'), 'Chrome');
      expect(AppLabelHelper.cleanPackageName('com.instagram.android'), 'Instagram');
      expect(AppLabelHelper.cleanPackageName('com.zhiliaoapp.musically'), 'TikTok');
      expect(AppLabelHelper.cleanPackageName('com.google.android.youtube'), 'YouTube');
      expect(AppLabelHelper.cleanPackageName('com.google.android.gm'), 'Gmail');
      expect(AppLabelHelper.cleanPackageName('com.google.android.apps.docs'), 'Google Docs');
      expect(AppLabelHelper.cleanPackageName('com.google.android.apps.maps'), 'Google Maps');
      expect(AppLabelHelper.cleanPackageName('com.google.android.dialer'), 'Phone');
      expect(AppLabelHelper.cleanPackageName('com.whatsapp'), 'WhatsApp');
      expect(AppLabelHelper.cleanPackageName('com.netflix.mediaclient'), 'Netflix');
      expect(AppLabelHelper.cleanPackageName('com.reddit.frontpage'), 'Reddit');
      expect(AppLabelHelper.cleanPackageName('com.pinterest'), 'Pinterest');
      expect(AppLabelHelper.cleanPackageName('com.twitter.android'), 'X (Twitter)');
      expect(AppLabelHelper.cleanPackageName('com.snapchat.android'), 'Snapchat');
    });

    test('Derives readable names from arbitrary reverse-domain packages', () {
      expect(AppLabelHelper.cleanPackageName('com.matiks.app'), 'Matiks');
      expect(AppLabelHelper.cleanPackageName('org.telegram.messenger'), 'Telegram');
      expect(AppLabelHelper.cleanPackageName('com.spotify.music'), 'Spotify');
      expect(AppLabelHelper.cleanPackageName('threads.net'), 'Threads');
      expect(AppLabelHelper.cleanPackageName('com.slack'), 'Slack');
      expect(AppLabelHelper.cleanPackageName('org.wikipedia'), 'Wikipedia');
      expect(AppLabelHelper.cleanPackageName('com.duolingo'), 'Duolingo');
    });

    test('Handles underscore and hyphen formatting properly', () {
      expect(AppLabelHelper.cleanPackageName('com.example.mind_valley'), 'Mind Valley');
      expect(AppLabelHelper.cleanPackageName('com.test.focus-timer'), 'Focus Timer');
    });

    test('Handles edge cases gracefully', () {
      expect(AppLabelHelper.cleanPackageName(''), '');
      expect(AppLabelHelper.cleanPackageName('   '), '');
      expect(AppLabelHelper.cleanPackageName('notepad'), 'Notepad');
    });
  });
}

