// Environment links
const links = {
    Production: {
        'Support Link 1': 'production-support-link1.html',
        'Support Link 2': 'production-support-link2.html',
        'Operations Link 1': 'production-operations-link1.html',
        'Operations Link 2': 'production-operations-link2.html',
        'Analytics Link 1': 'production-analytics-link1.html',
        'Analytics Link 2': 'production-analytics-link2.html'
    },
    Staging: {
        'Support Link 1': 'staging-support-link1.html',
        'Support Link 2': 'staging-support-link2.html',
        'Operations Link 1': 'staging-operations-link1.html',
        'Operations Link 2': 'staging-operations-link2.html',
        'Analytics Link 1': 'staging-analytics-link1.html',
        'Analytics Link 2': 'staging-analytics-link2.html'
    },
    Development: {
        'Support Link 1': 'development-support-link1.html',
        'Support Link 2': 'development-support-link2.html',
        'Operations Link 1': 'development-operations-link1.html',
        'Operations Link 2': 'development-operations-link2.html',
        'Analytics Link 1': 'development-analytics-link1.html',
        'Analytics Link 2': 'development-analytics-link2.html'
    }
};

const envDropdown = document.getElementById('envDropdown');
const leftPaneLinks = document.querySelectorAll('#menuList .button');
const iframe = document.querySelector('iframe');

// Set initial environment
let selectedEnvironment = envDropdown.value;

// Set initial page
iframe.src = links[selectedEnvironment]['Support Link 1'];

// Environment dropdown change handler
envDropdown.addEventListener('change', function() {
    selectedEnvironment = this.value;
    updateLinks();
    loadPage('Support Link 1'); // Default to Support Link 1 on environment change
});

// Update menu links based on environment
function updateLinks() {
    leftPaneLinks.forEach(link => {
        link.classList.remove('selected');
        link.addEventListener('click', function() {
            loadPage(this.innerText);
        });
    });
}

// Load page based on selected link
function loadPage(linkText) {
    iframe.src = links[selectedEnvironment][linkText];
    leftPaneLinks.forEach(link => {
        if (link.innerText === linkText) {
            link.classList.add('selected');
        } else {
            link.classList.remove('selected');
        }
    });
}

// Left pane toggle button handler
document.getElementById('leftToggleButton').addEventListener('click', function() {
    document.querySelector('.left-pane').classList.toggle('collapsed-left');
    this.innerHTML = document.querySelector('.left-pane').classList.contains('collapsed-left') ? '&#9654;' : '&#9664;';
});

// Date display
document.getElementById('date').textContent = new Date().toLocaleDateString();

// Ensure the correct environment is selected on initial load
document.addEventListener('DOMContentLoaded', function () {
    document.getElementById('envDropdown').dispatchEvent(new Event('change'));
});
