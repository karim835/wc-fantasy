# 🚀 Guide de démarrage rapide - WC Fantasy Rapport LaTeX

Vous avez converti votre rapport PDF en LaTeX! Voici comment l'utiliser en 5 minutes.

---

## ⚡ 5 étapes pour commencer

### 1️⃣ Compiler le rapport en PDF

**Option A - Ligne de commande:**
```bash
cd D:\pfa\rapport
pdflatex main.tex
pdflatex main.tex    # Deux fois pour la table des matières
```

**Option B - VS Code (recommandé):**
- Installer extension "LaTeX Workshop"
- Ouvrir `main.tex`
- Cliquer le bouton "Build" (ou Ctrl+Alt+B)

**Option C - Overleaf en ligne:**
- Créer un nouveau projet
- Importer tous les fichiers `.tex`
- Compiler en un clic

### 2️⃣ Modifier un chapitre

Exemple: Modifier l'introduction

```bash
# Ouvrir dans votre éditeur préféré
code chapters/introduction.tex    # VS Code
# ou
notepad chapters/introduction.tex # Notepad
```

Ensuite, recompiler (Ctrl+Alt+B dans VS Code ou `pdflatex main.tex` en CLI).

### 3️⃣ Ajouter du contenu

Pour ajouter une nouvelle section dans le Chapitre 1:

```latex
% Dans chapters/chapitre1.tex

\section{Ma nouvelle section}

Voici mon texte...

\subsection{Une sous-section}

Plus de détails ici.
```

Recompiler ensuite.

### 4️⃣ Ajouter une image

```latex
\begin{figure}[h]
    \centering
    \includegraphics[width=0.8\textwidth]{images/ma_figure.png}
    \caption{Mon image}
    \label{fig:ma_figure}
\end{figure}

Voir Figure \ref{fig:ma_figure}.
```

### 5️⃣ Ajouter un tableau

```latex
\begin{center}
    \begin{tabular}{|l|l|}
        \hline
        \textbf{Colonne 1} & \textbf{Colonne 2} \\
        \hline
        Donnée 1 & Donnée 2 \\
        \hline
    \end{tabular}
\end{center}
```

---

## 📁 Structure complète

```
rapport/
├── main.tex                ← À COMPILER
├── preamble.tex           ← Styles (ne pas toucher)
├── chapters/
│   ├── remerciements.tex
│   ├── resume.tex
│   ├── introduction.tex
│   ├── chapitre1.tex      ← Modifier ici
│   ├── chapitre2.tex      ← Ou ici
│   ├── chapitre3.tex
│   ├── chapitre4.tex
│   ├── conclusion.tex
│   ├── bibliographie.tex
│   └── annexes.tex
├── README.md              ← Documentation complète
├── STRUCTURE.md           ← Navigation détaillée
└── GUIDE_RAPIDE.md       ← Vous êtes ici!
```

---

## 🎨 Formatage rapide

| Besoin | Code LaTeX |
|--------|-----------|
| **Gras** | `\textbf{texte}` |
| *Italique* | `\textit{texte}` |
| Souligné | `\underline{texte}` |
| Coleur | `{\color{darkblue}texte}` |
| Code | `` `code` `` |

---

## 📝 Commandes utiles

```latex
% En-tête (auto-généré)
\chapter{Titre du chapitre}

% Section
\section{Mon titre}

% Sous-section
\subsection{Mon sous-titre}

% Liste à puces
\begin{itemize}
    \item Point 1
    \item Point 2
\end{itemize}

% Liste numérotée
\begin{enumerate}
    \item Premier
    \item Deuxième
\end{enumerate}

% Boîte d'information
\begin{infobox}
    Contenu important
\end{infobox}

% Référence croisée
\label{sec:maresource}
\ref{sec:maresource}

% Lien
\url{https://example.com}
\href{https://example.com}{Texte du lien}
```

---

## 🔍 Avant de soumettre

- [ ] ✅ Compiler 2 fois (`pdflatex main.tex` deux fois)
- [ ] ✅ Vérifier que `main.pdf` est généré
- [ ] ✅ Vérifier table des matières (pages correctes?)
- [ ] ✅ Vérifier pas d'erreurs LaTeX (console)
- [ ] ✅ Vérifier numérotation des références
- [ ] ✅ Vérifier liens cliquables (dans PDF)

---

## ❌ Problèmes courants et solutions

### ❌ "Undefined control sequence"
**Cause:** Oubli backslash ou typo  
**Solution:** Vérifier la commande LaTeX (ex: `\textbf` pas `\text_bf`)

### ❌ "File not found"
**Cause:** Chemin fichier incorrect  
**Solution:** Vérifier le chemin image/fichier

### ❌ "Table of Contents incorrect"
**Cause:** Pas compilé 2 fois  
**Solution:** Relancer compilation 2 fois

### ❌ "PDF non généré"
**Cause:** Erreur LaTeX grave  
**Solution:** Lire messages d'erreur console en détail

---

## 🚀 Après completion

### Pour envoyer au jury:
1. Compiler final: `pdflatex main.tex` (2 fois)
2. Renommer: `WC_Fantasy_Rapport_PFA_2026.pdf`
3. Archiver source: `rapport.zip` (all .tex files)
4. Envoyer:
   - PDF compilé au jury
   - Source ZIP en backup

### Pour continuer en développement:
```bash
# Garder la source LaTeX à jour
git add rapport/
git commit -m "Update rapport: Add new section"

# Ou simplement sauvegarder
cp rapport/ rapport_backup_v2/
```

---

## 📚 Documentation complète

Pour plus de détails, consulter:
- **README.md** - Guide complet
- **STRUCTURE.md** - Navigation chapitre par chapitre
- **Rapport_original.txt** - Contenu du PDF original

---

## 💡 Astuce pro

### Si vous modifiez souvent:
Installer VS Code + LaTeX Workshop extension
```bash
# Windows
choco install vscode
# vs code: Installer extension "LaTeX Workshop"

# Ubuntu/Linux
sudo apt install texlive-full code
```

Ensuite:
- Ouvrir `rapport/` comme dossier dans VS Code
- Auto-build sur save (Ctrl+S)
- Voir PDF preview côté droit

---

## ❓ Questions?

Référez-vous à:
- [Overleaf LearnLaTeX (FR)](https://www.overleaf.com/learn/latex/Learn_LaTeX_in_30_minutes)
- [TeX Stack Exchange](https://tex.stackexchange.com/)
- Console d'erreurs LaTeX (regarder les numéros de ligne)

---

## 🎯 Résumé en 1 minute

```bash
# Compiler
pdflatex main.tex

# Éditer un fichier
code chapters/chapitre1.tex

# Recompiler
pdflatex main.tex

# Visualiser
# main.pdf apparaît dans le dossier rapport/
```

**C'est tout! Vous êtes prêt.** 🎉

---

*Généré le: 13 Juin 2026*  
*Projet: WC Fantasy - Rapport PFA*  
*Format: LaTeX (compilable → PDF)*
