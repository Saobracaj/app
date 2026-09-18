//! Serbian Cyrillic → Latin transliteration.
//!
//! The question bank and the law are Cyrillic, but most people in Serbia type
//! their searches in Latin («testovi za vozački ispit», «saobraćajni znakovi»),
//! and a search engine does not treat the two scripts as one language. A page
//! that carries its text in both scripts is found either way, so the
//! prerendered copy of a question adds the Latin spelling next to the Cyrillic
//! one (a script toggle is a common thing on Serbian sites — this is the same
//! content, not a second page).
//!
//! The mapping is the official one (Правопис): one letter to one letter, with
//! љ/њ/џ becoming digraphs. A capital digraph is written `Lj`, not `LJ`,
//! unless the whole word is upper-case — the same rule a person follows.

/// Transliterates Serbian Cyrillic into Latin; anything that is not Cyrillic
/// (digits, Latin letters, punctuation) is kept as it is.
pub fn to_latin(text: &str) -> String {
    let chars: Vec<char> = text.chars().collect();
    let mut out = String::with_capacity(text.len());
    for (at, &c) in chars.iter().enumerate() {
        match latin(c) {
            Some(latin) => {
                // «ЉУБАВ» -> «LJUBAV», «Љубав» -> «Ljubav»: a capital digraph
                // follows the case of the letter after it.
                if latin.chars().count() == 2 && c.is_uppercase() {
                    let next_upper = chars
                        .get(at + 1)
                        .map(|n| n.is_uppercase() || !n.is_alphabetic())
                        .unwrap_or(true)
                        && chars
                            .get(at.wrapping_sub(1))
                            .map(|p| p.is_uppercase() || !p.is_alphabetic())
                            .unwrap_or(true);
                    if next_upper {
                        out.push_str(&latin.to_uppercase());
                    } else {
                        out.push_str(latin);
                    }
                } else {
                    out.push_str(latin);
                }
            }
            None => out.push(c),
        }
    }
    out
}

/// Whether the text has any Cyrillic in it — a page that is already Latin
/// gains nothing from a second copy.
pub fn has_cyrillic(text: &str) -> bool {
    text.chars().any(|c| latin(c).is_some())
}

fn latin(c: char) -> Option<&'static str> {
    Some(match c {
        'а' => "a",
        'б' => "b",
        'в' => "v",
        'г' => "g",
        'д' => "d",
        'ђ' => "đ",
        'е' => "e",
        'ж' => "ž",
        'з' => "z",
        'и' => "i",
        'ј' => "j",
        'к' => "k",
        'л' => "l",
        'љ' => "lj",
        'м' => "m",
        'н' => "n",
        'њ' => "nj",
        'о' => "o",
        'п' => "p",
        'р' => "r",
        'с' => "s",
        'т' => "t",
        'ћ' => "ć",
        'у' => "u",
        'ф' => "f",
        'х' => "h",
        'ц' => "c",
        'ч' => "č",
        'џ' => "dž",
        'ш' => "š",
        'А' => "A",
        'Б' => "B",
        'В' => "V",
        'Г' => "G",
        'Д' => "D",
        'Ђ' => "Đ",
        'Е' => "E",
        'Ж' => "Ž",
        'З' => "Z",
        'И' => "I",
        'Ј' => "J",
        'К' => "K",
        'Л' => "L",
        'Љ' => "Lj",
        'М' => "M",
        'Н' => "N",
        'Њ' => "Nj",
        'О' => "O",
        'П' => "P",
        'Р' => "R",
        'С' => "S",
        'Т' => "T",
        'Ћ' => "Ć",
        'У' => "U",
        'Ф' => "F",
        'Х' => "H",
        'Ц' => "C",
        'Ч' => "Č",
        'Џ' => "Dž",
        'Ш' => "Š",
        _ => return None,
    })
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn every_letter_of_the_alphabet_has_its_latin_form() {
        assert_eq!(
            to_latin("Непосредно регулисање саобраћаја на путевима врше:"),
            "Neposredno regulisanje saobraćaja na putevima vrše:"
        );
        assert_eq!(
            to_latin("љубав, њива, џеп, ђак, ћуп, чај, шума, жаба"),
            "ljubav, njiva, džep, đak, ćup, čaj, šuma, žaba"
        );
    }

    #[test]
    fn capital_digraphs_follow_the_word() {
        assert_eq!(to_latin("Љубав"), "Ljubav");
        assert_eq!(to_latin("ЉУБАВ"), "LJUBAV");
        assert_eq!(to_latin("Њ"), "NJ");
    }

    #[test]
    fn latin_and_digits_pass_through() {
        assert_eq!(to_latin("Oснове (B) 41"), "Osnove (B) 41");
        assert!(has_cyrillic("Питање"));
        assert!(!has_cyrillic("Pitanje 7921"));
    }
}
