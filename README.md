# olga-alternadores

<!-- aviso-ia -->
> **Feito com IA.** O código deste repositório foi escrito pelo **Claude Code** (inteligência artificial da Anthropic), a partir das especificações, dos testes e da revisão do autor. Leia antes de usar, como faria com qualquer código.

Icones de bandeja para Windows: alternar tela (duplicar/estender), saida de audio (com mudo), ejetar disco, taxa de atualizacao (Hz) tela scope (2a tela 1920x804/1920x1080 para o DCP-o-matic Player) e, no instalador, o menu classico no clique direito do Windows 11

| Icone | O que faz |
|---|---|
| AlternarTela | Clique alterna a 2a tela entre Duplicar e Estender. |
| AlternarAudio | Clique vai para a proxima saida de audio; depois da ultima, mudo (icone com X vermelho). Botao direito lista todas e tem o item Mudo. |
| EjetarDisco | Menu com os discos externos para ejetar; mostra qual programa segura o disco. Tambem pode ficar no clique direito do HD no Explorador ("Ejetar disco (OLGA)"; no Windows 11, em "Mostrar mais opcoes"). |
| TaxaTela | O icone mostra a taxa atual (Hz). Cada clique passa para a proxima taxa disponivel na resolucao atual, com um aviso grande; a troca so acontece 2,5 s depois do ultimo clique, para a tela nao piscar a cada opcao. Botao direito: taxas para trocar na hora e qual tela o clique muda. So muda a frequencia (nao mexe na resolucao, nao desfaz o scope do TelaScope). |
| TelaScope | Clique alterna a 2a tela entre scope (1920x804) e padrao (1920x1080). Tambem corrige o DCP-o-matic Player 2.18 em modo duas telas, que abre a janela de imagem com 1920x1080 numa tela scope e faz o flat vazar para a tela principal. |
| MenuClassico | Nao e icone: opcao do instalador que deixa o clique direito do Explorador no Windows 11 igual ao menu classico (completo, sem "Mostrar mais opcoes"). Grava uma chave em HKCU e reinicia o Explorador; desmarcar volta ao menu do Windows 11. Sem efeito no Windows 10. |

**Requisito do TelaScope:** a resolucao personalizada 1920x804 precisa existir para a 2a tela no painel da placa de video (NVIDIA: Painel de Controle > Alterar resolucao > Personalizar; AMD: Adrenalin > Resolucoes personalizadas; Intel: Graphics Command Center). Funciona com qualquer placa; sem essa resolucao o icone avisa ao tentar trocar.

**Instalar:** botao direito em `instalar.ps1` > Executar com o PowerShell. Abre uma janela para escolher quais icones instalar (o que ja esta instalado vem marcado; desmarcar desinstala). Copia para `C:\Scripts`, cria atalhos na Inicializacao do Windows e abre os icones.

Sem janela: `instalar.ps1 -Itens AlternarAudio,TaxaTela` (instala/atualiza so esses), `-Todos`, `-Remover TelaScope`. Nomes: AlternarTela, AlternarAudio, EjetarDisco, EjetarMenu, TaxaTela, TelaScope, MenuClassico.

Espelho da pasta `OLGA_SOFTWARE\ALTERNADORES`. Instaladores (.exe) e dependencias grandes ficam nos Releases.
