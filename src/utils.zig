pub fn is_digit(c: u8) bool {
    return c >= '0' and c <= '9';
}

pub fn is_alpha(c: u8) bool {
    return (c >= 'a' and c <= 'z') or (c >= 'A' and c <= 'Z');
}

pub fn is_alpha_numeric(c: u8) bool {
    return is_alpha(c) or is_digit(c);
}
