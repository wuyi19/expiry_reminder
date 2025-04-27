const reminderForm = document.getElementById('reminderForm');
const reminderList = document.getElementById('reminderList');

reminderForm.addEventListener('submit', function(event) {
  event.preventDefault();

  const itemName = document.getElementById('itemName').value.trim();
  const expiryDate = document.getElementById('expiryDate').value;

  if (itemName && expiryDate) {
    addReminder(itemName, expiryDate);
    reminderForm.reset();
  }
});

function addReminder(name, date) {
  const li = document.createElement('li');
  const daysLeft = calculateDaysLeft(date);

  li.textContent = `${name} - ${date} （剩余 ${daysLeft} 天）`;
  if (daysLeft <= 3) {
    li.style.color = 'red';
  }
  reminderList.appendChild(li);
}

function calculateDaysLeft(date) {
  const now = new Date();
  const expiry = new Date(date);
  const diffTime = expiry - now;
  return Math.ceil(diffTime / (1000 * 60 * 60 * 24));
}
