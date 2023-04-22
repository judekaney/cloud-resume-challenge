if (!localStorage.getItem('visited')) {
    fetch('https://uv0lnpu95j.execute-api.us-east-1.amazonaws.com/prod/visitorget', {
      method: 'GET',
      headers: {
        'Origin': 'https://judekaney.com',
        'Visited': 'unviewed'
      }
    })
    .then(response => {
      return response.json();
    })
    .then(data => {
      const count = data.total;
      document.getElementById("count").textContent = count;
      localStorage.setItem('visited', true);
    })
    .catch(error => {
      console.error(error);
    });
  } else {
    fetch('https://uv0lnpu95j.execute-api.us-east-1.amazonaws.com/prod/visitorget', {
      method: 'GET',
      headers: {
        'Origin': 'https://judekaney.com',
        'Visited': 'viewed'
      }
    })
    .then(response => {
      return response.json();
    })
    .then(data => {
      const count = data.total;
      document.getElementById("count").textContent = count;
    })
    .catch(error => {
      console.error(error);
    });
  }
  
