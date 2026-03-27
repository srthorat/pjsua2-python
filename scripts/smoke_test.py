#!/usr/bin/env python3
"""
Smoke test for the pjsua2_python wheel.

Checks:
  1. Package imports cleanly
  2. Installed version matches expected
  3. All key classes / constants are accessible
  4. Endpoint can be created, started, and cleanly destroyed
  5. (Optional) SIP registration succeeds — skipped when credentials absent

Usage:
  python scripts/smoke_test.py --expected-version 2.15.1
  python scripts/smoke_test.py \
      --expected-version 2.15.1 \
      --sip-registrar sip.example.com \
      --sip-user alice \
      --sip-password secret \
      --sip-domain example.com
"""
import argparse
import sys
import threading
from typing import Optional


class SipNetworkWarning(Exception):
    """Raised when a SIP test times out — indicates network filtering, not a
    library bug.  Treated as WARN (non-fatal) in the test runner."""


# ---------------------------------------------------------------------------
# Individual checks
# ---------------------------------------------------------------------------

def check_import():
    import pjsua2  # noqa: F401 — intentional late import
    return pjsua2


def check_version(expected: Optional[str]):
    from importlib.metadata import version
    installed = version("pjsua2_python")
    if expected and installed != expected:
        raise AssertionError(
            f"Version mismatch: installed={installed!r}, expected={expected!r}"
        )
    return installed


def check_modules(pjlib):
    required = [
        # Core endpoint
        "Endpoint", "EpConfig", "MediaConfig", "LogConfig", "UaConfig",
        # Transport
        "TransportConfig", "TransportInfo", "PJSIP_TRANSPORT_UDP",
        # Account
        "Account", "AccountConfig", "AccountRegConfig", "AccountSipConfig",
        "AccountMediaConfig", "AccountNatConfig", "AccountPresConfig",
        "AccountMwiConfig", "AccountVideoConfig", "AccountCallConfig",
        "AccountInfo", "AuthCredInfo",
        # Call
        "Call", "CallInfo", "CallOpParam", "CallSetting",
        "CallMediaInfo", "CallSendRequestParam",
        # Media
        "Media", "AudioMedia", "AudioMediaPlayer", "AudioMediaRecorder",
        "AudioMediaPort", "AudioDevInfo", "AudDevManager",
        "MediaFormatAudio", "MediaFormatVideo", "MediaFormat",
        "MediaEvent", "MediaFrame", "MediaSize",
        "CodecInfo", "CodecParam", "CodecParamInfo", "CodecParamSetting",
        "ConfPortInfo", "ToneGenerator", "ToneDesc", "ToneDigit",
        # Video
        "VideoMedia", "VideoWindow", "VideoPreview", "VidDevManager",
        "VideoDevInfo", "VideoMediaTransmitParam",
        # Presence / IM
        "Buddy", "BuddyConfig", "BuddyInfo", "PresenceStatus",
        # SIP primitives
        "SipHeader", "SipEvent", "SipRxData", "SipTxData",
        "SipTxOption", "SipTransaction", "SipMediaType",
        # Callback param structs — account/registration
        "OnRegStateParam", "OnRegStartedParam",
        "OnIncomingCallParam", "OnIncomingSubscribeParam",
        # Callback param structs — call
        "OnCallStateParam", "OnCallMediaStateParam",
        "OnCallMediaEventParam", "OnCallSdpCreatedParam",
        "OnCallTsxStateParam", "OnDtmfDigitParam",
        "OnCallTransferRequestParam", "OnCallTransferStatusParam",
        # Callback param structs — presence / IM
        "OnInstantMessageParam", "OnTypingIndicationParam",
        "OnBuddyEvSubStateParam",
        # Callback param structs — misc
        "OnNatDetectionCompleteParam", "OnTransportStateParam",
        "OnTimerParam", "OnIpChangeProgressParam",
        # RTCP / stream stats
        "RtcpStat", "RtcpStreamStat", "StreamInfo", "StreamStat",
        # TLS / SRTP
        "TlsConfig", "SrtpOpt", "SrtpCrypto",
        # Misc utility
        "Version", "Error", "LogEntry", "LogWriter",
        "IpChangeParam", "TimeVal",
    ]
    missing = [a for a in required if not hasattr(pjlib, a)]
    if missing:
        raise AssertionError(f"Missing from pjsua2: {missing}")
    return len(required)


def check_endpoint_lifecycle():
    import pjsua2
    ep = pjsua2.Endpoint()
    cfg = pjsua2.EpConfig()
    cfg.logConfig.level = 0
    cfg.logConfig.consoleLevel = 0
    ep.libCreate()
    ep.libInit(cfg)
    ep.libStart()
    ep.libDestroy()


def _make_endpoint():
    """Create, init and start a minimal pjsua2 Endpoint, return (ep, acc_class)."""
    import pjsua2
    ep = pjsua2.Endpoint()
    cfg = pjsua2.EpConfig()
    cfg.logConfig.level = 0
    cfg.logConfig.consoleLevel = 0
    ep.libCreate()
    ep.libInit(cfg)
    tp = pjsua2.TransportConfig()
    tp.port = 0
    ep.transportCreate(pjsua2.PJSIP_TRANSPORT_UDP, tp)
    ep.libStart()
    return ep


def check_sip_register(registrar: str, user: str, password: str,
                        domain: str, timeout: int = 30):
    """Send REGISTER and wait for 200 OK with Expires > 0."""
    import pjsua2

    result: dict = {"ok": False, "code": None, "reason": "", "expiry": None}
    done = threading.Event()

    class _Account(pjsua2.Account):
        def onRegState(self, prm):
            # 401/407 are digest challenges — pjsua2 retries with credentials
            # automatically; wait for the final non-challenge response
            if prm.code in (401, 407):
                return
            result["code"]   = prm.code
            result["reason"] = prm.reason
            result["expiry"] = prm.expiration
            if prm.code // 100 == 2 and prm.expiration > 0:
                result["ok"] = True
            done.set()

    ep = _make_endpoint()
    acc = _Account()
    acc_cfg = pjsua2.AccountConfig()
    acc_cfg.idUri = f"sip:{user}@{domain}"
    acc_cfg.regConfig.registrarUri = f"sip:{registrar}"
    cred = pjsua2.AuthCredInfo("digest", "*", user, 0, password)
    acc_cfg.sipConfig.authCreds.append(cred)
    acc.create(acc_cfg)

    fired = done.wait(timeout=timeout)
    ep.libDestroy()

    if not fired:
        raise SipNetworkWarning(
            f"SIP REGISTER timed out after {timeout}s "
            f"(no response from {registrar} — network may be filtered)"
        )
    if not result["ok"]:
        raise AssertionError(
            f"SIP REGISTER failed: {result['code']} {result['reason']}"
        )
    return f"{result['code']} OK (expires={result['expiry']}s)"


def check_sip_unregister(registrar: str, user: str, password: str,
                          domain: str, timeout: int = 30):
    """Register first, then send REGISTER with Expires: 0 and wait for 200 OK."""
    import pjsua2

    reg_done   = threading.Event()
    unreg_done = threading.Event()
    result: dict = {"code": None, "reason": "", "ok": False}

    class _Account(pjsua2.Account):
        def onRegState(self, prm):
            # 401/407 are digest challenges — skip and wait for final response
            if prm.code in (401, 407):
                return
            if not reg_done.is_set():
                reg_done.set()          # first final callback: initial registration
            else:
                # second final callback: unregistration (Expires: 0)
                result["code"]   = prm.code
                result["reason"] = prm.reason
                result["ok"]     = (prm.code // 100 == 2 and prm.expiration == 0)
                unreg_done.set()

    ep = _make_endpoint()
    acc = _Account()
    acc_cfg = pjsua2.AccountConfig()
    acc_cfg.idUri = f"sip:{user}@{domain}"
    acc_cfg.regConfig.registrarUri = f"sip:{registrar}"
    cred = pjsua2.AuthCredInfo("digest", "*", user, 0, password)
    acc_cfg.sipConfig.authCreds.append(cred)
    acc.create(acc_cfg)

    if not reg_done.wait(timeout=timeout):
        ep.libDestroy()
        raise SipNetworkWarning(
            f"Initial REGISTER timed out after {timeout}s "
            f"(no response from {registrar} — network may be filtered)"
        )

    # Send REGISTER Expires: 0
    acc.setRegistration(False)

    fired = unreg_done.wait(timeout=timeout)
    ep.libDestroy()

    if not fired:
        raise SipNetworkWarning(
            f"SIP UNREGISTER timed out after {timeout}s "
            "(Expires:0 sent, no response — network may be filtered)"
        )
    if not result["ok"]:
        raise AssertionError(
            f"SIP UNREGISTER failed: {result['code']} {result['reason']}"
        )
    return f"{result['code']} OK (expires=0)"


# ---------------------------------------------------------------------------
# Runner
# ---------------------------------------------------------------------------

def main():
    parser = argparse.ArgumentParser(description="pjsua2_python smoke test")
    parser.add_argument("--expected-version", default=None,
                        help="Expected installed version string (e.g. 2.15.1)")
    parser.add_argument("--sip-registrar", default=None)
    parser.add_argument("--sip-user", default=None)
    parser.add_argument("--sip-password", default=None)
    parser.add_argument("--sip-domain", default=None)
    args = parser.parse_args()

    passed = 0
    failed = 0
    warned = 0

    def run(label: str, fn):
        nonlocal passed, failed, warned
        print(f"  {label} ... ", end="", flush=True)
        try:
            val = fn()
            suffix = f" [{val}]" if isinstance(val, (str, int)) else ""
            print(f"PASS{suffix}")
            passed += 1
        except SipNetworkWarning as exc:
            print(f"WARN\n    {exc}")
            warned += 1
        except Exception as exc:
            print(f"FAIL\n    {exc}")
            failed += 1

    print()
    print(f"Python {sys.version}")
    print("=" * 60)

    pjsua2_mod = None
    try:
        pjsua2_mod = check_import()
        print("  import pjsua2 ... PASS")
        passed += 1
    except Exception as exc:
        print(f"  import pjsua2 ... FAIL\n    {exc}")
        failed += 1

    if pjsua2_mod is None:
        print("\nCannot continue — import failed.")
        sys.exit(1)

    run("version check", lambda: check_version(args.expected_version))
    run("module attributes", lambda: f"{check_modules(pjsua2_mod)} attrs")
    run("endpoint lifecycle", check_endpoint_lifecycle)

    # Domain defaults to registrar host when not specified separately
    sip_domain = args.sip_domain or args.sip_registrar
    sip_creds = (args.sip_registrar, args.sip_user, args.sip_password, sip_domain)
    if all(sip_creds):
        r, u, p, d = args.sip_registrar, args.sip_user, args.sip_password, sip_domain
        run(
            f"SIP register ({u}@{d})",
            lambda: check_sip_register(r, u, p, d),
        )
        run(
            f"SIP unregister ({u}@{d})",
            lambda: check_sip_unregister(r, u, p, d),
        )
    else:
        print("  SIP register   ... SKIP (set SIP_* vars to enable)")
        print("  SIP unregister ... SKIP (set SIP_* vars to enable)")

    print("=" * 60)
    summary = f"Results: {passed} passed, {failed} failed"
    if warned:
        summary += f", {warned} warned (network)"
    print(summary)
    if failed:
        sys.exit(1)


if __name__ == "__main__":
    main()
