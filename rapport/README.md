# WC Fantasy - Rapport PFA en LaTeX

Ce dossier contient la conversion complète du rapport PDF PFA en code LaTeX, facilitant la manipulation et la modification du document.

## 📁 Structure des fichiers

```
rapport/
├── main.tex                          # Document principal (à compiler)
├── preamble.tex                      # Configuration LaTeX (packages, styles, couleurs)
├── chapters/                         # Chapitres du rapport
│   ├── remerciements.tex            # Remerciements
│   ├── resume.tex                   # Résumé et Abstract
│   ├── introduction.tex             # Introduction générale
│   ├── chapitre1.tex               # Contexte et Problématique
│   ├── chapitre2.tex               # État de l'Art
│   ├── chapitre3.tex               # Spécification et Conception
│   ├── chapitre4.tex               # Implémentation et Résultats
│   ├── conclusion.tex              # Conclusion générale
│   ├── bibliographie.tex           # Références et webographie
│   └── annexes.tex                 # Annexes techniques
├── Rapport.txt                       # Extraction texte du PDF (backup)
└── README.md                         # Ce fichier
```

## 🚀 Utilisation

### Compiler le document

**Avec MiKTeX ou TeX Live:**
```bash
pdflatex main.tex
pdflatex main.tex  # 2 passes pour TOC correct
```

**Avec un IDE LaTeX (VS Code + LaTeX Workshop, Overleaf, etc.):**
- Ouvrir `main.tex`
- Cliquer sur "Build"

### Résultat
Le fichier `main.pdf` sera généré dans le même dossier.

## ✏️ Modifications du rapport

Chaque chapitre est dans un fichier séparé pour faciliter les modifications:

### Modifier un chapitre
1. Ouvrir le fichier correspondant dans `chapters/`
2. Éditer le contenu LaTeX
3. Recompiler `main.tex`

### Ajouter du contenu
Exemple: Ajouter une section dans Chapitre 1
```latex
\section{Nouvelle section}

Du texte ici...

\subsection{Sous-section}

Plus de contenu...
```

### Ajouter une image
```latex
\begin{figure}[h]
    \centering
    \includegraphics[width=0.8\textwidth]{path/to/image.png}
    \caption{Description de l'image}
    \label{fig:reference}
\end{figure}

% Référence : voir Figure \ref{fig:reference}
```

### Ajouter un tableau
```latex
\begin{center}
    \begin{tabularx}{\linewidth}{|l|X|}
        \hline
        \textbf{Colonne 1} & \textbf{Colonne 2} \\
        \hline
        Valeur 1 & Valeur 2 \\
        \hline
    \end{tabularx}
\end{center}
```

## 🎨 Personnalisation du style

Tous les styles (couleurs, polices, espacements) sont définis dans `preamble.tex`.

### Modifier les couleurs
```latex
% Dans preamble.tex
\definecolor{darkblue}{RGB}{0, 51, 102}      % Couleur primaire
\definecolor{lightgray}{RGB}{240, 240, 240}  % Couleur secondaire
```

### Modifier les marges
```latex
\usepackage[margin=2.5cm, top=2.5cm, bottom=2.5cm]{geometry}
```

### Modifier l'interligne
```latex
\onehalfspacing  % 1.5 (défaut)
% ou
\doublespacing   % 2.0
```

## 📖 Commandes utiles LaTeX

### Formatage du texte
```latex
\textbf{Texte en gras}
\textit{Texte en italique}
\underline{Texte souligné}
\texttt{Texte monospace}
\color{darkblue}{Texte coloré}
```

### Listes
```latex
\begin{enumerate}
    \item Premier item
    \item Deuxième item
\end{enumerate}

\begin{itemize}
    \item Puce 1
    \item Puce 2
\end{itemize}
```

### Boîtes
```latex
\begin{infobox}
    Contenu important en boîte bleue
\end{infobox}
```

### Références croisées
```latex
\label{sec:montitre}           % Créer une référence
voir Section \ref{sec:montitre} % Référencer
```

### Liens hypertexte
```latex
\url{https://example.com}
\href{https://example.com}{Texte du lien}
```

## 📝 Fichiers importants

### `main.tex`
- Point d'entrée principal
- Charge tous les chapitres avec `\input{}`
- Configure la page de titre
- Génère table des matières automatiquement

### `preamble.tex`
- Configuration complète du document
- Tous les packages LaTeX
- Définition des couleurs et styles
- Personnalisation des en-têtes/pieds de page

### `chapters/remerciements.tex` à `chapters/annexes.tex`
- Contenu principal du rapport
- Chaque chapitre indépendant

## 🔧 Dépannage

### Erreur: Package not found
**Solution:** Installer le package LaTeX manquant
```bash
# Windows (MiKTeX)
miktex-console.exe
# Chercher et installer le package

# Linux
sudo apt-get install texlive-latex-extra
```

### Erreur: Undefined control sequence
**Cause:** Oubli du package ou typo dans une commande LaTeX
**Solution:** Vérifier la commande et les packages dans `preamble.tex`

### Table des matières incorrecte
**Solution:** Compiler 2 fois (LaTeX génère le TOC en première passe, l'insère en seconde)

## 📊 Statistiques du document

- **Chapitres:** 4 + Introduction + Conclusion
- **Pages:** ~42 (original PDF)
- **Tables:** 8 principales
- **Figures:** 10 référencées
- **Annexes:** 3 (Endpoints, Variables d'env, Migrations)
- **Références bibliographiques:** 20+

## 💡 Conseils

1. **Versionner avec Git:** Chaque chapitre est petit → facile à merger
2. **Compiler régulièrement:** Détecter les erreurs tôt
3. **Garder le style uniforme:** Utiliser les commandes prédéfinies
4. **Documenter les changements:** Ajouter des commentaires % dans le code
5. **Backups:** La fichier `Rapport.txt` contient l'extraction texte du PDF original

## 📞 Support

Pour des questions LaTeX:
- [Overleaf Learn LaTeX in 30 minutes](https://www.overleaf.com/learn)
- [The LaTeX Wikibook](https://en.wikibooks.org/wiki/LaTeX)
- [TeX Stack Exchange](https://tex.stackexchange.com/)

---

**Généré:** 2026-06-13  
**Format:** LaTeX (compilable en PDF)  
**Projet:** WC Fantasy - Rapport PFA  
**École:** EMSI - Informatique et Réseaux
