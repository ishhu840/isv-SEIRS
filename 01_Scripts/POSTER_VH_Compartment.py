"""
Integrated Host-Vector Compartmental Diagram
Strictly matching the reference style:
  • Boxes contain ONLY the compartment symbol (big, italic)
  • Arrow labels are SHORT single symbols 
  • ALL arrows are perfectly straight (except waning immunity arc)
"""
import matplotlib.pyplot as plt
import matplotlib.patches as mpatches
import matplotlib.lines as mlines
import os

# ── Canvas ────────────────────────────────────────────────────────────────────
W, H = 15.0, 10.5
fig, ax = plt.subplots(figsize=(W, H))
ax.set_xlim(0, W); ax.set_ylim(0, H)
ax.axis('off')
fig.patch.set_facecolor('white')

# ── Colours ───────────────────────────────────────────────────────────────────
OR  = '#F5CBA7'; OR_E = '#CA6F1E'   # orange  — vector
BL  = '#AED6F1'; BL_E = '#2E86C1'   # blue    — human
AQ  = '#D4E6F1'; AQ_E = '#5DADE2'   # light blue — aquatic
K   = '#2C3E50'                      # near-black text
GR  = '#7F8C8D'                      # grey annotations

BW = 1.30   # box width
BH = 1.05   # box height
G  = 0.08   # gap

# ── Coordinates ───────────────────────────────────────────────────────────────
yA = 8.5   # Aquatic & Males
yV = 5.5   # Vector Females
yH = 2.5   # Humans

# Vector Row (Left to Right)
xv_SW = 4.0; xv_EW = 7.0; xv_IW = 10.0; xv_NI = 13.0
# Human Row (Right to Left)
xh_SH = 10.0; xh_EH = 7.0; xh_IH = 4.0; xh_RH = 1.0
# Aquatic Row
xa_A = 7.0; xa_NMW = 4.0; xa_NMI = 13.0

# ═════════════════════════════════════════════════════════════════════════════
# DRAWING UTILITIES
# ═════════════════════════════════════════════════════════════════════════════
def draw_box(cx, cy, fc, ec):
    ax.add_patch(mpatches.FancyBboxPatch(
        (cx - BW/2, cy - BH/2), BW, BH,
        boxstyle='round,pad=0.06',
        fc=fc, ec=ec, lw=2.2, zorder=3))

def sym(cx, cy, text, size=28, col=K):
    ax.text(cx, cy, text, fontsize=size, ha='center', va='center',
            color=col, fontstyle='italic', fontfamily='serif', zorder=5)

def arrow(x_start, y_start, x_end, y_end, col=K, lw=1.8, ls='solid'):
    ax.annotate('', xy=(x_end, y_end), xytext=(x_start, y_start),
        arrowprops=dict(
            arrowstyle='->', color=col, lw=lw, mutation_scale=18,
            linestyle=ls))

def alabel(x, y, text, sz=15, col=K, ha='center', va='center', bg=False):
    kw = {}
    if bg:
        kw['bbox'] = dict(fc='white', ec='none', boxstyle='round,pad=0.18', zorder=7)
    ax.text(x, y, text, fontsize=sz, ha=ha, va=va,
            color=col, fontstyle='italic', fontfamily='serif', zorder=8, **kw)

# ═════════════════════════════════════════════════════════════════════════════
# BOXES
# ═════════════════════════════════════════════════════════════════════════════
# Top Row: Aquatic & Males
draw_box(xa_A, yA, AQ, AQ_E); sym(xa_A, yA, r'$A$', col='#1B4F72')
draw_box(xa_NMW, yA, OR, OR_E); sym(xa_NMW, yA, r'$N_{MW}$', col='#7B241C', size=22)
draw_box(xa_NMI, yA, OR, OR_E); sym(xa_NMI, yA, r'$N_{MI}$', col='#7B241C', size=22)

# Mid Row: Females
draw_box(xv_SW, yV, OR, OR_E); sym(xv_SW, yV, r'$S_W$', col='#7B241C', size=24)
draw_box(xv_EW, yV, OR, OR_E); sym(xv_EW, yV, r'$E_W$', col='#7B241C', size=24)
draw_box(xv_IW, yV, OR, OR_E); sym(xv_IW, yV, r'$I_W$', col='#7B241C', size=24)
draw_box(xv_NI, yV, OR, OR_E); sym(xv_NI, yV, r'$N_I$', col='#7B241C', size=24)

# Bot Row: Humans (Reversed order to create circular flow!)
draw_box(xh_SH, yH, BL, BL_E); sym(xh_SH, yH, r'$S_H$', col='#154360', size=24)
draw_box(xh_EH, yH, BL, BL_E); sym(xh_EH, yH, r'$E_H$', col='#154360', size=24)
draw_box(xh_IH, yH, BL, BL_E); sym(xh_IH, yH, r'$I_H$', col='#154360', size=24)
draw_box(xh_RH, yH, BL, BL_E); sym(xh_RH, yH, r'$R_H$', col='#154360', size=24)

# ═════════════════════════════════════════════════════════════════════════════
# ARROWS & LABELS
# ═════════════════════════════════════════════════════════════════════════════

# Aquatic to Adults
arrow(xa_A - BW/2 - G, yA - 0.2, xv_SW + 0.2, yV + BH/2 + G)
alabel((xa_A + xv_SW)/2, (yA + yV)/2 + 0.4, r'$G$', sz=15)

arrow(xa_A - BW/2 - G, yA, xa_NMW + BW/2 + G, yA)
alabel((xa_A + xa_NMW)/2, yA + 0.3, r'$G$', sz=15)

arrow(xa_A + BW/2 + G, yA - 0.2, xv_NI - BW/2 - G, yV + BH/2 + G, col=OR_E)
alabel((xa_A + xv_NI)/2, (yA + yV)/2 + 0.4, r'$\nu_{eff}$', sz=15, col=OR_E, bg=True)

arrow(xa_A + BW/2 + G, yA, xa_NMI - BW/2 - G, yA, col=OR_E)
alabel((xa_A + xa_NMI)/2, yA + 0.3, r'$\nu_{eff}$', sz=15, col=OR_E, bg=True)

# Eggs into A
arrow(xa_A, yV + BH/2 + 0.5, xa_A, yA - BH/2 - G)
alabel(xa_A - 0.7, yV + BH/2 + 1.2, r'$EFD(T)$', sz=14)

# Climate variables T* and R*
arrow(xa_A - 1.2, yA + 1.0, xa_A - G, yA + BH/2)
alabel(xa_A - 1.4, yA + 1.2, r'$R^*$', sz=16, col='#2980B9')

arrow(xv_EW + 1.5, yV + 1.0, xv_EW + 1.5, yV + 0.3)
alabel(xv_EW + 1.5, yV + 1.3, r'$T^*$', sz=16, col='#C0392B')

# Releases
arrow(xa_NMI + BW/2 + 1.2, yA, xa_NMI + BW/2 + G, yA, col='#8E44AD', lw=2.5)
alabel(xa_NMI + BW/2 + 0.6, yA + 0.3, r'$Release$', sz=13, col='#8E44AD')

# Females Progression (Left to Right)
arrow(xv_SW + BW/2 + G, yV, xv_EW - BW/2 - G, yV)
arrow(xv_EW + BW/2 + G, yV, xv_IW - BW/2 - G, yV)
alabel((xv_EW + xv_IW)/2, yV + 0.3, r'$PDR(T)$', sz=15)

# Humans Progression (Right to Left)
arrow(xh_SH - BW/2 - G, yH, xh_EH + BW/2 + G, yH)
arrow(xh_EH - BW/2 - G, yH, xh_IH + BW/2 + G, yH)
arrow(xh_IH - BW/2 - G, yH, xh_RH + BW/2 + G, yH)
alabel((xh_EH + xh_SH)/2, yH + 0.3, r'$\lambda_H$', sz=15)
alabel((xh_IH + xh_EH)/2, yH + 0.3, r'$\sigma_H$', sz=15)
alabel((xh_RH + xh_IH)/2, yH + 0.3, r'$\gamma_H$', sz=15)

# Human Births
arrow(xh_SH + BW/2 + 1.0, yH, xh_SH + BW/2 + G, yH)
alabel(xh_SH + BW/2 + 0.5, yH + 0.3, r'$B_H$', sz=15)

# Waning Immunity Arc (from R_H back to S_H)
ax.annotate('', xy=(xh_SH - 0.2, yH - BH/2),
            xytext=(xh_RH + 0.2, yH - BH/2),
    arrowprops=dict(arrowstyle='->', color=GR, lw=1.8, mutation_scale=18,
                    connectionstyle='arc3,rad=-0.25'))
alabel((xh_SH + xh_RH)/2, yH - BH/2 - 1.2, r'$\omega$', sz=15, col=GR)

# Death Arrows
for x in [xh_RH, xh_IH, xh_EH, xh_SH]:
    arrow(x, yH - BH/2, x, yH - BH/2 - 0.5)
    alabel(x, yH - BH/2 - 0.7, r'$\mu_H$', sz=13)

for x in [xv_SW, xv_EW, xv_IW, xv_NI]:
    arrow(x, yV - BH/2, x, yV - BH/2 - 0.5)
    alabel(x, yV - BH/2 - 0.7, r'$lf(T)$', sz=13)

# Aquatic Death
arrow(xa_A + BW/2, yA + BH/2, xa_A + BW/2 + 0.5, yA + BH/2 + 0.5)
alabel(xa_A + BW/2 + 0.7, yA + BH/2 + 0.7, r'$\mu_A$', sz=13)

# ═════════════════════════════════════════════════════════════════════════════
# CROSSING DOTTED ARROWS (Dengue Coupling & ISV Blocking)
# ═════════════════════════════════════════════════════════════════════════════
# 1. I_W -> S_H (Dengue to Humans). PERFECTLY VERTICAL!
arrow(xv_IW, yV - BH/2 - G, xh_SH, yH + BH/2 + G, col=K, lw=2.5, ls=(0, (5, 3)))
alabel(xv_IW, (yV + yH)/2, r'$\lambda_H$', sz=18, col=K, bg=True)

# 2. I_H -> S_W (Dengue to Vectors). PERFECTLY VERTICAL!
arrow(xh_IH, yH + BH/2 + G, xv_SW, yV - BH/2 - G, col=K, lw=2.5, ls=(0, (5, 3)))
alabel(xv_SW, (yV + yH)/2, r'$\lambda_V$', sz=18, col=K, bg=True)

# 3. N_I -> S_H (ISV Blocking)
arrow(xv_NI - BW/2, yV - BH/2 - G, xh_SH + BW/2, yH + BH/2 + G, col='#E67E22', lw=3.0, ls=(0, (4, 2)))
alabel((xv_NI + xh_SH)/2, (yV + yH)/2, r'$\varepsilon$', sz=22, col='#D35400', bg=True)

# ═════════════════════════════════════════════════════════════════════════════
# Mating Venereal Pathway
# ═════════════════════════════════════════════════════════════════════════════
arrow(xa_NMI, yA - BH/2 - G, xv_SW + BW/2, yV + BH/2 + G, col='#8E44AD', lw=2.0, ls=(0, (3, 2)))
alabel((xa_NMI + xv_SW)/2, (yA + yV)/2, r'$\nu_V$', sz=16, col='#8E44AD', bg=True)

# Labels
ax.text(W/2, 9.8, 'ISV & Vector Population Dynamics', fontsize=16, ha='center', color=K, fontweight='bold')
ax.text(W/2, 1.0, 'Human Host SEIRS Dynamics', fontsize=16, ha='center', color=K, fontweight='bold')

os.makedirs('../02_Figures', exist_ok=True)
plt.savefig('../02_Figures/POSTER_Fig0_Integrated.png', dpi=300, bbox_inches='tight', facecolor='white')
plt.savefig('/Users/ishtiaq/.gemini/antigravity/brain/0c1ca6ed-e859-4d3b-98ca-121a0325dbaa/POSTER_Fig0_Integrated.png', dpi=300, bbox_inches='tight', facecolor='white')
plt.close()
print("Saved POSTER_Fig0_Integrated.png to 02_Figures")
