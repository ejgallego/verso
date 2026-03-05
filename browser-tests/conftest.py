import json
import pytest
import random
import socket
import subprocess
import time
from pathlib import Path
from playwright.sync_api import sync_playwright

def default_site_dir() -> Path:
    repo_root = Path(__file__).resolve().parents[1]
    if repo_root.parent.name == ".worktrees":
        return repo_root.parents[1] / "_out" / repo_root.name / "html-multi"
    return repo_root / "_out" / "html-multi"


DEFAULT_SITE_DIR = default_site_dir()


def find_free_port():
    """Find an available port by binding to port 0."""
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
        s.bind(('127.0.0.1', 0))
        return s.getsockname()[1]

def load_redirects(site_dir: str | Path):
    """Load redirects from JSON file and return a list of (source, target) tuples."""
    json_path = Path(site_dir)
    if not json_path.is_absolute():
        json_path = (Path(__file__).parent / json_path).resolve()
    json_path = json_path / "xref.json"
    with open(json_path) as f:
        data = json.load(f)

    sections = data['Verso.Genre.Manual.section']['contents']
    return [(s, sections[s][0]['address'] + '#' + sections[s][0]['id']) for s in sections]

def get_sample_redirects(n=10):
    """Get a random sample of n redirects for testing."""
    redirects = load_redirects(DEFAULT_SITE_DIR)
    if len(redirects) <= n:
        return redirects
    return random.sample(redirects, n)

def pytest_addoption(parser):
    parser.addoption(
        "--port",
        action="store",
        default=None,
        help="Port for the local test server (default: auto-select)"
    )
    parser.addoption(
        "--site-dir",
        action="store",
        default=str(DEFAULT_SITE_DIR),
        help="Path to the built site directory"
    )
    parser.addoption(
        "--server-url",
        action="store",
        default=None,
        help="Use an existing server instead of starting one (e.g., http://localhost:3000)"
    )
    parser.addoption(
        "--num-redirects",
        action="store",
        default=10,
        type=int,
        help="Number of random redirects to test (default: 10)"
    )
    parser.addoption(
        "--seed",
        action="store",
        default=None,
        type=int,
        help="Random seed for reproducible redirect selection"
    )

def pytest_configure(config):
    """Set random seed if provided."""
    seed = config.getoption("--seed")
    if seed is not None:
        random.seed(seed)

def pytest_generate_tests(metafunc):
    """Generate test cases for each sampled redirect."""
    if "redirect_case" in metafunc.fixturenames:
        n = metafunc.config.getoption("--num-redirects")
        redirects = load_redirects(metafunc.config.getoption("--site-dir"))
        if len(redirects) > n:
            redirects = random.sample(redirects, n)
        # Create readable test IDs
        ids = [f"{source}->{target}" for source, target in redirects]
        metafunc.parametrize("redirect_case", redirects, ids=ids)

@pytest.fixture(scope="session")
def server(request):
    """Start a local HTTP server for the built site, or use an existing one."""
    external_url = request.config.getoption("--server-url")

    if external_url:
        yield external_url
        return

    site_dir = request.config.getoption("--site-dir")
    site_dir = Path(site_dir)
    if not site_dir.is_absolute():
        site_dir = (Path(__file__).parent / site_dir).resolve()
    port = request.config.getoption("--port")

    if port is None:
        port = find_free_port()
    else:
        port = int(port)

    proc = subprocess.Popen(
        ["python", "-m", "http.server", str(port), "--bind", "127.0.0.1"],
        cwd=site_dir,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL
    )
    time.sleep(1)
    yield f"http://127.0.0.1:{port}"
    proc.terminate()
    proc.wait()

@pytest.fixture(scope="session")
def playwright_instance():
    with sync_playwright() as p:
        yield p

@pytest.fixture(scope="session", params=["chromium", "firefox"])
def browser(request, playwright_instance):
    """Parameterized fixture to run tests in multiple browsers."""
    browser_type = request.param
    browser = getattr(playwright_instance, browser_type).launch()
    yield browser
    browser.close()

@pytest.fixture
def page(browser):
    page = browser.new_page()
    yield page
    page.close()
