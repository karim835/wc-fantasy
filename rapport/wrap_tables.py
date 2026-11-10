import os
import glob
import re

captions = [
    ("Catégorie", "Technologies disponibles par catégorie"),
    ("Critère", "Comparaison des applications existantes"),
    ("\\#", "Besoins fonctionnels du système"),
    ("Exigence", "Besoins non fonctionnels"),
    ("Récapitulatif", "Récapitulatif des choix technologiques"),
    ("Rôle", "Schéma de la base de données"),
    ("Justification", "Justification des choix technologiques"),
    ("Outil / Logiciel", "Outils et logiciels de développement"),
    ("Dossier", "Structure du projet"),
    ("Action / Événement", "Barème de points fantasy"),
    ("Écran / Module", "Interfaces de l'application"),
    ("Scénario testé", "Scénarios de tests réalisés"),
    ("Difficulté rencontrée", "Difficultés rencontrées et solutions apportées"),
    ("Méthode \\+ Route", "Principaux endpoints REST de l'API"),
    ("Variable", "Variables d'environnement"),
    ("Fichier", "Liste des migrations SQL")
]

files = glob.glob('d:/pfa/rapport/chapters/*.tex')

for f in files:
    with open(f, 'r', encoding='utf-8') as file:
        content = file.read()
    
    blocks = re.split(r'\\begin\{center\}', content)
    if len(blocks) == 1:
        continue
        
    new_content = blocks[0]
    for block in blocks[1:]:
        if '\\begin{tabular' in block:
            header_match = re.search(r'\\rowcolor\{emsigreen\}[^\n]+', block)
            caption_text = "Tableau"
            if header_match:
                header_line = header_match.group(0)
                for key, cap in captions:
                    if re.search(key, header_line, re.IGNORECASE):
                        caption_text = cap
                        break
            
            block = block.replace('\\end{center}', '\\caption{' + caption_text + '}\n\\end{table}', 1)
            new_content += '\\begin{table}[H]\n\\centering' + block
        else:
            new_content += '\\begin{center}' + block
            
    with open(f, 'w', encoding='utf-8') as file:
        file.write(new_content)

print("Tables wrapped successfully.")
