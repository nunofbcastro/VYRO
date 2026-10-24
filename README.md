# VYRO — Nutrição e treino

Aplicação Flutter demonstrativa para nutrição e treino, com interface em português (Portugal) e inglês, tema escuro, claro ou definido pelo sistema.

## Executar

Com o Flutter instalado, a partir da raiz do projeto:

```sh
flutter pub get
flutter run
```

O projeto nesta fase contém a base de interface da Fase 1. O menu Perfil permite trocar idioma e tema. A galeria Sistema de design está disponível em `/design-system` ou no ecrã Perfil.

## Estado

- Diário nutricional: adicionar, editar e eliminar alimentos em SQLite local; os valores são calculados por porção a partir dos nutrientes por 100 g e os campos desconhecidos ficam desconhecidos.
- Leitor EAN-8/EAN-13/UPC-A para Android e iOS; consulta explícita à Open Food Facts, cache local, atribuição e entrada manual sem câmara. No Web, o código é introduzido manualmente.
- O dashboard, os planos de treino e o progresso ainda apresentam dados fictícios identificados como demonstração.
- Reconhecimento de refeições por fotografia, programação/registo real de treinos, análise de movimento, exportação e eliminação total de dados serão implementados nas fases seguintes.
- A especificação, tokens e guia visual permanecem em `docs/` e `brand/`.
