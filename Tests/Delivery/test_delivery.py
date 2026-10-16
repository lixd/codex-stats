#!/usr/bin/env python3
"""Real filesystem, codesign and LaunchServices checks, confined to UUID fixtures."""
import hashlib
import json
import os
from pathlib import Path
import plistlib
import shutil
import signal
import subprocess
import sys
import tempfile
import time
import uuid


ROOT = Path(__file__).resolve().parents[2]
WORK = Path(tempfile.mkdtemp(prefix="codexstats-delivery-test."))
IDENTIFIER = "local.codexstats.delivery-test." + str(uuid.uuid4())
RECEIPT = WORK / "launch.json"
APP_NAME = "Codex Stats.app"
CONTROL = WORK / "fixture"
HELPER = WORK / "app-delivery"
passed = 0


def run(*args, success=True):
    result = subprocess.run([str(arg) for arg in args], text=True, stdout=subprocess.PIPE,
                            stderr=subprocess.STDOUT, timeout=90)
    if (result.returncode == 0) != success:
        raise AssertionError(f"Unexpected exit {result.returncode}: {args}\n{result.stdout}")
    return result.stdout


def check(label):
    global passed
    passed += 1
    print(f"PASS {label}", flush=True)


def digest(app):
    digest = hashlib.sha256()
    for path in sorted(app.rglob("*")):
        digest.update(str(path.relative_to(app)).encode())
        digest.update(str(path.lstat().st_mode).encode())
        if path.is_file():
            digest.update(path.read_bytes())
    return digest.hexdigest()


def sign(app):
    run("/usr/bin/codesign", "--force", "--sign", "-", "--timestamp=none", app)


def fixture(name, version, **extra):
    app = WORK / name / APP_NAME
    (app / "Contents/MacOS").mkdir(parents=True)
    (app / "Contents/Resources").mkdir()
    shutil.copy2(CONTROL, app / "Contents/MacOS/Fixture")
    metadata = dict(CFBundleIdentifier=IDENTIFIER, CFBundlePackageType="APPL",
                    CFBundleExecutable="Fixture", CFBundleName="Delivery Test",
                    CFBundleShortVersionString=str(version), CFBundleVersion=str(version),
                    LSUIElement=True, DeliveryTestReceipt=str(RECEIPT))
    metadata.update(extra)
    (app / "Contents/Info.plist").write_bytes(plistlib.dumps(metadata))
    sign(app)
    return app


def install(source, destination, success=True):
    return run(ROOT / "Scripts/install-local.sh", "--source", source,
               "--destination", destination, success=success)


def rejected(source, destination, phrase, label):
    before = digest(destination)
    output = install(source, destination, success=False)
    assert phrase in output, output
    assert digest(destination) == before, label
    check(label + "; previous bundle unchanged")


def compilation_checkout(candidate):
    checkout = WORK / "checkout"
    (checkout / "Scripts").mkdir(parents=True)
    for name in ("build-macos.sh", "app-delivery.swift"):
        shutil.copy2(ROOT / "Scripts" / name, checkout / "Scripts" / name)
    (checkout / "Assets").mkdir()
    shutil.copy2(candidate / "Contents/Info.plist", checkout / "Assets/Info.plist")
    (checkout / "Sources/Core").mkdir(parents=True)
    (checkout / "Sources/App").mkdir()
    (checkout / "Sources/Core/invalid.swift").write_text("this is an intentional syntax error\n")
    (checkout / "Sources/App/main.swift").write_text("import AppKit\n")
    return checkout


def interrupt_build(checkout, previous):
    before = digest(previous)
    process = subprocess.Popen([str(checkout / "Scripts/build-macos.sh"), str(previous.parent)],
                               stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                               text=True, start_new_session=True)
    try:
        deadline = time.monotonic() + 60
        while time.monotonic() < deadline and process.poll() is None:
            staged = list(previous.parent.glob(".codexstats-build.*/Codex Stats.app/Contents/Info.plist"))
            if staged:
                # A separate process group owns only this fixture build and its compilers.
                os.killpg(process.pid, signal.SIGKILL)
                process.communicate(timeout=10)
                assert process.returncode == -signal.SIGKILL and digest(previous) == before
                assert staged[0].exists()  # SIGKILL did not run shell cleanup.
                check("SIGKILL before publication preserves previous bundle; owned staging remains")
                return
            time.sleep(0.01)
        raise AssertionError("Could not observe the pre-publication stage: " + process.communicate(timeout=10)[0])
    finally:
        if process.poll() is None:
            os.killpg(process.pid, signal.SIGKILL)
            process.communicate(timeout=10)


def nested_preflight(previous):
    before = (digest(previous), previous.stat().st_mtime_ns)
    output = install(previous, previous / "nested.app", success=False)
    assert "互相包含" in output
    after = (digest(previous), previous.stat().st_mtime_ns)
    assert before == after, f"Nested preflight wrote inside protected App: {before} != {after}"
    check("nested target rejected without even temporary writes inside source App")


def interrupt_nested_preflight(previous):
    before = (digest(previous), previous.stat().st_mtime_ns)
    process = subprocess.Popen([str(ROOT / "Scripts/install-local.sh"), "--source", str(previous),
                                "--destination", str(previous / "nested.app")],
                               stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                               text=True, start_new_session=True)
    helper_stages = []
    try:
        deadline = time.monotonic() + 60
        while time.monotonic() < deadline and process.poll() is None:
            helper_stages = list(Path("/tmp").glob(f"codexstats-install-helper.{process.pid}.*"))
            if helper_stages or list(previous.glob(".codexstats-install.*")):
                os.killpg(process.pid, signal.SIGKILL)
                process.communicate(timeout=10)
                assert process.returncode == -signal.SIGKILL
                assert (digest(previous), previous.stat().st_mtime_ns) == before
                assert helper_stages and all(not path.resolve().is_relative_to(previous.resolve()) for path in helper_stages)
                check("SIGKILL during installer preparation leaves protected App completely unchanged")
                return
            time.sleep(0.01)
        raise AssertionError("Could not observe installer preparation: " + process.communicate(timeout=10)[0])
    finally:
        if process.poll() is None:
            os.killpg(process.pid, signal.SIGKILL)
            process.communicate(timeout=10)
        for stage in helper_stages:
            shutil.rmtree(stage)


try:
    run("xcrun", "swiftc", "-swift-version", "5", "-framework", "AppKit",
        ROOT / "Tests/Delivery/main.swift", "-o", CONTROL)
    previous = fixture("target", 1)
    candidate = fixture("candidate", 2)
    nested_preflight(previous)
    interrupt_nested_preflight(previous)
    if "--preflight-only" in sys.argv:
        print("PASS focused preflight checks; no App process was signalled", flush=True)
        sys.exit(0)
    checkout = compilation_checkout(candidate)
    interrupt_build(checkout, previous)
    # The interrupted stage belongs to this test; remove it before subsequent checks.
    for stage in previous.parent.glob(".codexstats-build.*"):
        shutil.rmtree(stage)
    if "--interruption-only" in sys.argv:
        print("PASS focused interruption check; no App process was signalled", flush=True)
        sys.exit(0)
    run("xcrun", "swiftc", "-swift-version", "5", "-framework", "AppKit",
        ROOT / "Scripts/app-delivery.swift", "-o", HELPER)

    bad = fixture("bad-signature", 2)
    with (bad / "Contents/MacOS/Fixture").open("ab") as executable:
        executable.write(b"invalid-signature")
    rejected(bad, previous, "签名校验失败", "corrupted signature rejected")

    bad = fixture("missing-executable", 2)
    (bad / "Contents/MacOS/Fixture").unlink()
    rejected(bad, previous, "可执行文件缺失", "missing executable rejected")

    bad = fixture("bad-plist", 2)
    (bad / "Contents/Info.plist").write_bytes(plistlib.dumps({"CFBundleIdentifier": IDENTIFIER}))
    rejected(bad, previous, "信息不完整", "incomplete metadata rejected before copy")

    bad = fixture("foreign-identity", 2, CFBundleIdentifier=IDENTIFIER + ".other")
    rejected(bad, previous, "另一个 App", "different target identity rejected")

    bad = fixture("unreadable-copy", 2)
    unreadable = bad / "Contents/Resources/private.txt"
    unreadable.write_text("cannot copy this fixture resource")
    sign(bad)
    unreadable.chmod(0)
    try:
        rejected(bad, previous, "Permission denied", "real ditto read failure")
    finally:
        unreadable.chmod(0o644)

    alias = WORK / "alias.app"
    alias.symlink_to(previous, target_is_directory=True)
    before = digest(previous)
    output = install(candidate, alias, success=False)
    assert "符号链接" in output and alias.is_symlink() and digest(previous) == before
    check("destination symlink rejected")
    rejected(previous, previous, "不能相同", "same source and destination rejected")

    # A real compiler error in a minimal checkout using the unchanged build entry point.
    before = digest(previous)
    output = run(checkout / "Scripts/build-macos.sh", previous.parent, success=False)
    assert "error:" in output and digest(previous) == before
    check("real Swift compilation failure preserves previous build")

    # Successful publication really swaps both directory entries.
    staged = fixture("swap-stage", 2)
    old_digest, new_digest = digest(previous), digest(staged)
    run(HELPER, "publish", staged, previous, "build")
    assert digest(previous) == new_digest and digest(staged) == old_digest
    check("RENAME_SWAP publishes candidate and retains exact previous bundle")
    fresh = WORK / "fresh.app"
    run(HELPER, "publish", staged, fresh, "build")
    assert digest(fresh) == old_digest and not staged.exists()
    check("RENAME_EXCL publishes first installation")
    run(HELPER, "publish", fresh, previous, "build")
    assert plistlib.loads((previous / "Contents/Info.plist").read_bytes())["CFBundleVersion"] == "1"

    # The actual installer performs copy/signature validation/swap/LaunchServices launch.
    output = install(candidate, previous)
    deadline = time.monotonic() + 5
    while not RECEIPT.exists() and time.monotonic() < deadline:
        time.sleep(0.05)
    receipt = json.loads(RECEIPT.read_text())
    assert receipt["bundle"] == IDENTIFIER and receipt["version"] == "2" and receipt["build"] == "2"
    assert Path(receipt["path"]).resolve() == previous.resolve() and str(receipt["pid"]) in output, (receipt, output)
    assert digest(previous) == digest(candidate) and "已确认运行" in output
    check("real installer launches exact UUID/path/PID with in-process version receipt")

    rejected(candidate, previous, "正在运行", "running target refuses replacement without terminating it")
    elsewhere = fixture("elsewhere", 1)
    rejected(candidate, elsewhere, "正在运行", "same bundle at another path refuses installation")
    before = digest(previous)
    output = run(checkout / "Scripts/build-macos.sh", previous.parent, success=False)
    assert "正在运行" in output and "intentional syntax error" not in output and digest(previous) == before
    os.kill(receipt["pid"], 0)
    check("build refuses running destination before compilation; existing PID survives")
    run(CONTROL, "quit", IDENTIFIER)

    # Replacement succeeds but the new app immediately exits. Do not claim launch success.
    failed_launch = fixture("failed-launch", 3, DeliveryTestFailLaunch=True)
    before = digest(previous)
    output = install(failed_launch, previous, success=False)
    assert "App 已替换，但启动未确认" in output and "已确认运行" not in output
    recovery_line = next(line for line in output.splitlines() if line.startswith("旧副本保留在："))
    recovery = Path(recovery_line.split("：", 1)[1])
    assert recovery.is_relative_to(WORK) and digest(recovery) == before
    assert digest(previous) == digest(failed_launch)
    check("launch failure reported separately; exact previous bundle retained for recovery")
    print(f"PASS {passed} delivery checks; no production bundle or user Applications touched", flush=True)
finally:
    # Never use killall, bundle-name matching, or a production bundle identifier.
    if CONTROL.exists():
        run(CONTROL, "quit", IDENTIFIER)
    shutil.rmtree(WORK)
