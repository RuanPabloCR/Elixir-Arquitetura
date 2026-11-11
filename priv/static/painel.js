// Conecta o cliente do LiveView. `Phoenix` e `LiveView` sao globais carregados
// pelos scripts anteriores, servidos direto dos pacotes em deps/.
(function () {
  var csrf = document.querySelector("meta[name='csrf-token']").getAttribute("content");
  var liveSocket = new LiveView.LiveSocket("/live", Phoenix.Socket, {
    params: { _csrf_token: csrf }
  });

  liveSocket.connect();
  window.liveSocket = liveSocket;
})();
