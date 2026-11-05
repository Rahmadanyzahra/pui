package com.example.patara_ai;

import androidx.test.rule.ActivityTestRule;
import dev.flutter.plugins.integration_test.FlutterTestRunner;
import org.junit.Rule;
import org.junit.runner.RunWith;

// Menjalankan uji di folder integration_test/ sebagai uji instrumentasi Android, sehingga bisa dijalankan
// di perangkat sungguhan dari jarak jauh (Firebase Test Lab). Lihat pengujian/perangkat/.
@RunWith(FlutterTestRunner.class)
public class MainActivityTest {
  @Rule
  public ActivityTestRule<MainActivity> rule = new ActivityTestRule<>(MainActivity.class, true, false);
}
