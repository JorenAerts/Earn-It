package be.gloop.app.ui

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.safeDrawingPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.text.LinkAnnotation
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.TextLinkStyles
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.withLink
import androidx.compose.ui.text.withStyle
import androidx.compose.ui.unit.dp
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.window.DialogProperties
import be.gloop.app.R
import be.gloop.app.data.AppContent
import be.gloop.core.legal.LegalDocument
import be.gloop.core.legal.LegalDocumentKind

fun LegalDocumentKind.titleRes(): Int = when (this) {
    LegalDocumentKind.PRIVACY -> R.string.legal_privacy
    LegalDocumentKind.TERMS -> R.string.legal_terms
    LegalDocumentKind.HEALTH_SAFETY -> R.string.legal_health
    LegalDocumentKind.COMMUNITY -> R.string.legal_community
}

/**
 * Inline Markdown → styled text: `**bold**`, `[label](url)` and bare emails (→ mailto). Links to
 * `gloop-legal://<doc>` call [onLegal] instead of opening a browser.
 */
fun inlineMarkdown(text: String, linkColor: Color, onLegal: (LegalDocumentKind) -> Unit = {}): AnnotatedString = buildAnnotatedString {
    val pattern = Regex("""\*\*(.+?)\*\*|\[(.+?)]\((.+?)\)|([\w.+-]+@[\w-]+\.[\w.-]+)""")
    val links = TextLinkStyles(SpanStyle(color = linkColor, fontWeight = FontWeight.SemiBold))
    var last = 0
    for (m in pattern.findAll(text)) {
        append(text.substring(last, m.range.first))
        val (bold, label, url, email) = m.destructured
        when {
            bold.isNotEmpty() -> withStyle(SpanStyle(fontWeight = FontWeight.Bold)) { append(bold) }
            label.isNotEmpty() && url.startsWith("gloop-legal://") -> {
                val kind = LegalDocumentKind.entries.firstOrNull { it.file == url.removePrefix("gloop-legal://") }
                withLink(LinkAnnotation.Clickable(url, links) { kind?.let(onLegal) }) { append(label) }
            }
            label.isNotEmpty() -> withLink(LinkAnnotation.Url(url, links)) { append(label) }
            else -> withLink(LinkAnnotation.Url("mailto:$email", links)) { append(email) }
        }
        last = m.range.last + 1
    }
    append(text.substring(last))
}

/** "By continuing you accept the Terms and Privacy Policy." with tappable documents (iOS `LegalConsentLine`). */
@Composable
fun LegalConsentLine(modifier: Modifier = Modifier) {
    var showing by remember { mutableStateOf<LegalDocumentKind?>(null) }
    Text(inlineMarkdown(stringResource(R.string.ob_consent), MaterialTheme.colorScheme.primary) { showing = it },
        modifier, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant, textAlign = TextAlign.Center)
    showing?.let { LegalSheet(it) { showing = null } }
}

/** A legal document in-app (iOS `LegalDocumentView`): translation note + "Read in English". */
@Composable
fun LegalSheet(kind: LegalDocumentKind, onClose: () -> Unit) {
    val context = LocalContext.current
    var english by remember { mutableStateOf(false) }
    val content = remember { AppContent(context) }
    val doc = remember(english) { LegalDocument.load(kind, content, content.language, english) }
    Dialog(onDismissRequest = onClose, properties = DialogProperties(usePlatformDefaultWidth = false, decorFitsSystemWindows = false)) {
        Surface(Modifier.fillMaxSize()) {
            Column(Modifier.fillMaxSize().safeDrawingPadding()) {
                Row(Modifier.fillMaxWidth().padding(4.dp)) {
                    Spacer(Modifier.weight(1f))
                    TextButton(onClick = onClose) { Text(stringResource(R.string.done), fontWeight = FontWeight.SemiBold) }
                }
                Column(Modifier.verticalScroll(rememberScrollState()).padding(horizontal = 20.dp, vertical = 8.dp),
                    verticalArrangement = Arrangement.spacedBy(12.dp)) {
                    if (doc == null) { Text(stringResource(R.string.legal_missing)); return@Column }
                    Text(doc.title.ifBlank { stringResource(kind.titleRes()) }, style = MaterialTheme.typography.headlineMedium, fontWeight = FontWeight.Bold)
                    val translated = doc.isTranslation || english
                    if (translated || LegalDocument.load(kind, content, content.language)?.isTranslation == true) {
                        Card(colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.secondaryContainer), shape = RoundedCornerShape(14.dp)) {
                            Column(Modifier.padding(14.dp)) {
                                Text(stringResource(if (english) R.string.legal_english_original else R.string.legal_translated), style = MaterialTheme.typography.bodySmall)
                                TextButton(onClick = { english = !english }) {
                                    Text(stringResource(if (english) R.string.legal_show_translation else R.string.legal_read_english))
                                }
                            }
                        }
                    }
                    val link = MaterialTheme.colorScheme.primary
                    for (block in doc.blocks) when (block) {
                        is LegalDocument.Block.Heading -> Text(block.text, style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.Bold,
                            modifier = Modifier.padding(top = 8.dp))
                        is LegalDocument.Block.Paragraph -> Text(inlineMarkdown(block.text, link), style = MaterialTheme.typography.bodyMedium)
                        is LegalDocument.Block.Bullets -> Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
                            block.items.forEach { item ->
                                Row { Text("•", Modifier.width(18.dp)); Text(inlineMarkdown(item, link), style = MaterialTheme.typography.bodyMedium) }
                            }
                        }
                    }
                    Spacer(Modifier.padding(16.dp))
                }
            }
        }
    }
}
