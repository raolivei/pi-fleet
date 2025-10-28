Quero criar um projeto no GitHub chamado **us-law-severity-map**.  
O objetivo é gerar um **mapa dos Estados Unidos** mostrando, com cores, a severidade das leis de cada estado (mais escuro = mais severo, mais claro = mais brando).

Crie toda a estrutura do projeto com os seguintes arquivos:

1. **requirements.txt**

   - geopandas
   - matplotlib
   - requests

2. **main.py**

   - Baixe o shapefile oficial dos estados do U.S. Census (20m resolution).
   - Remova territórios e DC, mantendo apenas os 50 estados.
   - Crie um dicionário `scores` com severidade inicial, por exemplo:
     - 100 = estados com pena de morte ativa (TX, FL, AL, GA, MO, AZ, OK, etc.)
     - 80–95 = estados severos sem pena de morte, mas com leis rígidas (UT, LA, TN, IN, NV, NC, VA, etc.)
     - 40–60 = moderados (MI, PA, WI, MN, CO, NM, etc.)
     - 20–40 = brandos, sem pena de morte e mais foco em reabilitação (NY, IL, NJ, MA, CT, RI, VT, ME, HI, AK, WA, OR, CA, etc.)
   - Atribua severidade default = 50 para estados não listados.
   - Gere um mapa usando `matplotlib` + `geopandas.plot`, com colormap “Reds”, legenda e título:  
     **“Severidade das Leis por Estado (EUA)”**.
   - Mostrar o mapa na tela (`plt.show()`).

3. **README.md**

   - Nome do projeto: _US Law Severity Map_.
   - Explicação do que o projeto faz (mapa das severidades).
   - Instruções de instalação:
     ```bash
     git clone <repo>
     cd us-law-severity-map
     python -m venv venv
     source venv/bin/activate   # ou venv\Scripts\activate no Windows
     pip install -r requirements.txt
     python main.py
     ```
   - Critérios de severidade (100, 80–95, 40–60, 20–40).
   - Screenshot de exemplo (coloque “screenshot.png” como placeholder).
   - Licença MIT.

4. **LICENSE**
   - Use MIT License padrão.

Saída final: me entregue todos os arquivos completos (requirements.txt, main.py, README.md, LICENSE) prontos para serem salvos e rodados.
