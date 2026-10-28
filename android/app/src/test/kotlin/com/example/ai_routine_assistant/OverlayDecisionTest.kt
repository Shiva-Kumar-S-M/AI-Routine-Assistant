package com.example.ai_routine_assistant

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test

class OverlayDecisionTest {

    private val targetPackage = "com.instagram.android"
    private val launcherPackage = "com.google.android.apps.nexuslauncher"
    private val otherPackage = "com.whatsapp"

    @Before
    fun setUp() {
        UsageMonitorService.resetAllBypasses()
    }

    @Test
    fun testUnderLimitNeverShowsOverlay() {
        val now = 1000000L
        val shouldShow = UsageMonitorService.shouldShowOverlay(
            pkg = targetPackage,
            isOverLimit = false,
            lastForegroundPkg = launcherPackage,
            now = now
        )
        assertFalse("Under limit must never trigger overlay", shouldShow)
    }

    @Test
    fun testFirstAppOpenOverLimitShowsOverlay() {
        val now = 1000000L
        val shouldShow = UsageMonitorService.shouldShowOverlay(
            pkg = targetPackage,
            isOverLimit = true,
            lastForegroundPkg = launcherPackage,
            now = now
        )
        assertTrue("Opening an over-limit app from launcher must trigger overlay", shouldShow)
    }

    @Test
    fun testInSessionBypassSuppressesWhileInSameSession() {
        val now = 1000000L
        // 1. Initial open
        val firstOpen = UsageMonitorService.shouldShowOverlay(
            pkg = targetPackage,
            isOverLimit = true,
            lastForegroundPkg = launcherPackage,
            now = now
        )
        assertTrue(firstOpen)

        // 2. User clicks 'Continue anyway' (in-session bypass)
        UsageMonitorService.markSessionBypassed(targetPackage)
        UsageMonitorService.setDebounce(now)

        // 3. Next poll 2 seconds later while in same app
        val sameSessionPoll = UsageMonitorService.shouldShowOverlay(
            pkg = targetPackage,
            isOverLimit = true,
            lastForegroundPkg = targetPackage,
            now = now + 4000L // after debounce, but same session
        )
        assertFalse("In-session bypass must suppress overlay while in same session", sameSessionPoll)
    }

    @Test
    fun testOverlayTriggersOnRepeatedOpensAfterExiting() {
        var now = 1000000L

        // Open 1: from launcher
        assertTrue(UsageMonitorService.shouldShowOverlay(targetPackage, true, launcherPackage, now))
        UsageMonitorService.markSessionBypassed(targetPackage)

        // User leaves app (to launcher)
        UsageMonitorService.clearSessionBypass(targetPackage)
        now += 10000L

        // Open 2: from launcher
        assertTrue("2nd open must trigger overlay", UsageMonitorService.shouldShowOverlay(targetPackage, true, launcherPackage, now))
        UsageMonitorService.markSessionBypassed(targetPackage)

        // User leaves app (to another app e.g. WhatsApp)
        UsageMonitorService.clearSessionBypass(targetPackage)
        now += 10000L

        // Open 3: from WhatsApp
        assertTrue("3rd open must trigger overlay", UsageMonitorService.shouldShowOverlay(targetPackage, true, otherPackage, now))
        UsageMonitorService.markSessionBypassed(targetPackage)

        // User leaves app (to launcher)
        UsageMonitorService.clearSessionBypass(targetPackage)
        now += 10000L

        // Open 4: from launcher
        assertTrue("4th open must trigger overlay", UsageMonitorService.shouldShowOverlay(targetPackage, true, launcherPackage, now))
    }

    @Test
    fun testDebounceSuppressesFlickerImmediatelyAfterBypass() {
        val now = 1000000L
        UsageMonitorService.setDebounce(now)

        val immediatePoll = UsageMonitorService.shouldShowOverlay(
            pkg = targetPackage,
            isOverLimit = true,
            lastForegroundPkg = launcherPackage,
            now = now + 1000L // within 3s debounce
        )
        assertFalse("Debounce must suppress flicker within 3 seconds", immediatePoll)

        val afterDebounce = UsageMonitorService.shouldShowOverlay(
            pkg = targetPackage,
            isOverLimit = true,
            lastForegroundPkg = launcherPackage,
            now = now + 3500L // after 3s debounce
        )
        assertTrue("After debounce expires, new app open must show overlay", afterDebounce)
    }
}

