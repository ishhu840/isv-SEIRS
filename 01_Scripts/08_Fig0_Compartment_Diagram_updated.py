import matplotlib.pyplot as plt
import matplotlib.patches as mpatches
import os

# ── Canvas Setup (Much larger and spacious) ───────────────────────────────────
W, H = 22.0, 14.0
fig, ax = plt.subplots(figsize=(W, H))
ax.set_xlim(0, W); ax.set_ylim(0, H)
ax.axis('off')
fig.patch.set_facecolor('#FDFEFE')  # Clean bright background

# ── Vibrant Color Palette ─────────────────────────────────────────────────────
# Humans: Vibrant Blues/Teals
C_HUMAN = '#3498DB'
C_HUMAN_BG = '#EBF5FB'

# Vector Females: Vibrant Oranges/Corals
C_VECTOR = '#E67E22'
C_VECTOR_BG = '#FEF5E7'

# Aquatic / Males: Vibrant Greens/Mints
C_AQUA = '#2ECC71'
C_AQUA_BG = '#EAFAF1'

# Text and Arrows
C_TEXT = '#2C3E50'
C_ARROW = 'black'  # Update to use nice black color for arrows
C_DENGUE = 'black'
C_CFAV = 'black'

BW = 1.6   # box width
BH = 1.2   # box height

# ── Background Grouping Panels ────────────────────────────────────────────────
def add_panel(x, y, w, h, color, title, y_offset=0):
    ax.add_patch(mpatches.FancyBboxPatch((x, y), w, h, boxstyle='round,pad=0.2', 
                                         fc=color, ec='none', alpha=0.6, zorder=1))
    ax.text(x + w - 0.5, y + h - 0.4 - y_offset, title, fontsize=20, fontweight='bold', 
            color=C_TEXT, ha='right', va='top', zorder=2)

# Add large shaded regions for clarity
add_panel(1.0, 0.5, 20.0, 4.0, C_HUMAN_BG, "", y_offset=0.4)
add_panel(1.0, 5.0, 20.0, 4.0, C_VECTOR_BG, "Adult Female Vectors")
add_panel(1.0, 9.5, 20.0, 4.0, C_AQUA_BG, "Aquatic Stage & Male Vectors")

# ── Coordinates (Massively spaced out) ────────────────────────────────────────
yH = 2.0   # Human row
yV = 6.5   # Vector row
yA = 11.0  # Aquatic/Male row

# Aquatic / Males (Left to right)
x_A = 4.0; x_NMW = 11.0; x_NMI = 18.0

# Vector Females (Left to right)
x_SW = 4.0; x_EW = 8.5; x_IW = 13.0; x_NI = 18.0

# Humans (Right to left, so transmission drops straight down)
x_SH = 13.0; x_EH = 8.5; x_IH = 4.0; x_RH = 17.0

# ═════════════════════════════════════════════════════════════════════════════
# DRAWING UTILITIES
# ═════════════════════════════════════════════════════════════════════════════
def draw_box(cx, cy, fc, symbol, text_color='black'):
    # Ignore the passed fc, force white fill and black border
    ax.add_patch(mpatches.FancyBboxPatch(
        (cx - BW/2, cy - BH/2), BW, BH,
        boxstyle='round,pad=0.1',
        fc='white', ec='black', lw=2.5, zorder=4))
    ax.text(cx, cy, symbol, fontsize=32, ha='center', va='center',
            color=text_color, fontstyle='italic', fontfamily='serif', fontweight='bold', zorder=5)

def draw_arrow(x1, y1, x2, y2, color=C_ARROW, lw=2.5, ls='-', label='', lh=0, lv=0):
    # Force arrow color to the new C_ARROW (C_HUMAN)
    color = C_ARROW
    ax.annotate('', xy=(x2, y2), xytext=(x1, y1),
                arrowprops=dict(arrowstyle='-|>', color=color, lw=lw, mutation_scale=25, linestyle=ls), zorder=10)
    if label:
        ax.text((x1+x2)/2 + lh, (y1+y2)/2 + lv, label, fontsize=18, color='black', 
                ha='center', va='center', fontweight='bold', zorder=6) # No bbox/white background

# ═════════════════════════════════════════════════════════════════════════════
# COMPARTMENTS (Bright & Colorful)
# ═════════════════════════════════════════════════════════════════════════════
# Aquatic & Males
draw_box(x_A, yA, C_AQUA, r'$A$')
draw_box(x_NMW, yA, C_AQUA, r'$N_{MW}$')
draw_box(x_NMI, yA, C_CFAV, r'$N_{MI}$')

# Female Vectors
draw_box(x_SW, yV, C_VECTOR, r'$S_W$')
draw_box(x_EW, yV, C_VECTOR, r'$E_W$')
draw_box(x_IW, yV, C_DENGUE, r'$I_W$')
draw_box(x_NI, yV, C_CFAV, r'$N_I$')

# Humans
draw_box(x_SH, yH, C_HUMAN, r'$S_H$')
draw_box(x_EH, yH, C_HUMAN, r'$E_H$')
draw_box(x_IH, yH, C_DENGUE, r'$I_H$')
draw_box(x_RH, yH, C_HUMAN, r'$R_H$')

# ═════════════════════════════════════════════════════════════════════════════
# HORIZONTAL FLOWS (Progression)
# ═════════════════════════════════════════════════════════════════════════════
# Aquatic to Males
draw_arrow(x_A + BW/2, yA, x_NMW - BW/2, yA, label=r'$G$', lv=0.4)
draw_arrow(x_NMW + BW/2, yA, x_NMI - BW/2, yA, lw=3, label=r'Release', lv=0.4)

# Vector Females Progression
# S_W -> E_W: human-to-mosquito force of infection (Ross-Macdonald), NOT PDR.
# E_W -> I_W: extrinsic incubation period completion, governed by PDR(T).
draw_arrow(x_SW + BW/2, yV, x_EW - BW/2, yV, label=r'$\lambda_V$', lv=0.4)
draw_arrow(x_EW + BW/2, yV, x_IW - BW/2, yV, label=r'$PDR(T)$', lv=0.4)

# Human Progression (Right to Left!)
draw_arrow(x_SH - BW/2, yH, x_EH + BW/2, yH, label=r'$\lambda_H$', lv=0.4)
draw_arrow(x_EH - BW/2, yH, x_IH + BW/2, yH, label=r'$\sigma_H$', lv=0.4)

# I_H to R_H (Curved underneath, shifted slightly down to avoid overlap)
ax.annotate('', xy=(x_RH, yH - BH/2 - 0.1), xytext=(x_IH, yH - BH/2),
            arrowprops=dict(arrowstyle='-|>', color=C_ARROW, lw=2.5, mutation_scale=25,
                            connectionstyle='arc3,rad=0.15'), zorder=10)
ax.text(10.5, 0.85, r'$\gamma_H$', fontsize=18, color='black', ha='center', fontweight='bold')

# R_H back to S_H (Waning immunity)
draw_arrow(x_RH - BW/2, yH, x_SH + BW/2, yH, label=r'$\omega$', lv=0.4)

# ═════════════════════════════════════════════════════════════════════════════
# VERTICAL FLOWS (Births, Development, Cross-Infection)
# ═════════════════════════════════════════════════════════════════════════════
# S_W to Aquatic (Eggs)
draw_arrow(x_SW - 0.5, yV + BH/2, x_A - 0.5, yA - BH/2, label=r'$EFD(T)$', lh=-1.0)

# Aquatic to Females
draw_arrow(x_A + 0.5, yA - BH/2, x_SW + 0.5, yV + BH/2, label=r'$G$', lh=0.8)

# Maternal CFAV Transmission
draw_arrow(x_A + 1.0, yA - BH/2, x_NI - 1.0, yV + BH/2, ls='--', lw=3, label=r'$\nu_{eff}$', lh=0.5, lv=0.8)

# Venereal CFAV Transmission (Male to Female)
draw_arrow(x_NMI, yA - BH/2, x_SW + 1.0, yV + BH/2, ls='--', lw=3, label=r'$\nu_V$', lh=-0.5, lv=-0.5)

# Dengue: Mosquito to Human (Vertical Drop!)
draw_arrow(x_IW, yV - BH/2, x_SH, yH + BH/2, lw=4, label=r'$\lambda_H$', lh=0.5)

# Dengue: Human to Mosquito (Vertical Climb!)
draw_arrow(x_IH, yH + BH/2, x_SW, yV - BH/2, lw=4, label=r'$\lambda_V$', lh=-0.5)

# ISV Blocking Dengue
draw_arrow(x_NI - BW/2, yV - BH/2, x_SH + 1.0, yH + BH/2, ls='--', lw=3, label=r'BLOCKS ($\varepsilon$)', lh=1.4, lv=-0.2)
ax.text(20.5, 3.25, "Human SEIRS Dynamics", fontsize=20, fontweight='bold', color=C_TEXT, ha='right', va='center', zorder=6)

# ── Save the file ─────────────────────────────────────────────────────────────
os.makedirs('../02_Figures', exist_ok=True)
plt.savefig('../02_Figures/POSTER_Fig0_Integrated_Updated.png', dpi=300, bbox_inches='tight', facecolor='#FDFEFE')
print("Saved Beautiful Spacious POSTER_Fig0_Integrated_Updated.png to 02_Figures")
