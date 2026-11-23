# olga-alternadores

Icones de bandeja para Windows: alternar tela (duplicar/estender), saida de audio, ejetar disco e tela scope (2a tela 1920x804/1920x1080 para o DCP-o-matic Player)

| Icone | O que faz |
|---|---|
| AlternarTela | Clique alterna a 2a tela entre Duplicar e Estender. |
| AlternarAudio | Clique vai para a proxima saida de audio; botao direito lista todas. |
| EjetarDisco | Menu com os discos externos para ejetar; mostra qual programa segura o disco. |
| TelaScope | Clique alterna a 2a tela entre scope (1920x804) e padrao (1920x1080). Tambem corrige o DCP-o-matic Player 2.18 em modo duas telas, que abre a janela de imagem com 1920x1080 numa tela scope e faz o flat vazar para a tela principal. |

**Requisito do TelaScope:** a resolucao personalizada 1920x804 precisa existir para a 2a tela no painel da placa de video (NVIDIA: Painel de Controle > Alterar resolucao > Personalizar; AMD: Adrenalin > Resolucoes personalizadas; Intel: Graphics Command Center). Funciona com qualquer placa; sem essa resolucao o icone avisa ao tentar trocar.

**Instalar:** botao direito em `instalar.ps1` > Executar com o PowerShell. Copia para `C:\Scripts`, cria atalhos na Inicializacao do Windows e abre os icones.

Espelho da pasta `OLGA_SOFTWARE\ALTERNADORES`. Instaladores (.exe) e dependencias grandes ficam nos Releases.